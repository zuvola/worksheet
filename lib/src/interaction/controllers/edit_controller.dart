import 'package:any_date/any_date.dart';
import 'package:flutter/widgets.dart';

import '../../core/core.dart';
import 'rich_text_editing_controller.dart';

/// The result of committing a cell edit, including navigation direction.
///
/// Used by [CellEditorOverlay] to communicate both the committed value
/// and the desired post-commit navigation to the [Worksheet] widget.
@immutable
class EditCommitResult {
  /// The cell that was edited.
  final CellCoordinate cell;

  /// The committed value, or null if the cell was cleared.
  final CellValue? value;

  /// Row offset to move after commit (e.g. 1 for Enter, -1 for Shift+Enter).
  final int rowDelta;

  /// Column offset to move after commit (e.g. 1 for Tab, -1 for Shift+Tab).
  final int columnDelta;

  const EditCommitResult({
    required this.cell,
    required this.value,
    this.rowDelta = 0,
    this.columnDelta = 0,
  });
}

/// The current state of cell editing.
enum EditState {
  /// No editing is in progress.
  idle,

  /// A cell is being edited.
  editing,

  /// An edit is being committed.
  committing,
}

/// How the edit was initiated.
enum EditTrigger {
  /// Double-tap/click on a cell.
  doubleTap,

  /// Pressing F2 key.
  f2Key,

  /// Typing a character (starts with that character).
  typing,

  /// Programmatic start.
  programmatic,
}

/// Controls cell editing state for a worksheet.
///
/// Manages the lifecycle of cell editing:
/// - Start edit on: double-tap, F2, typing
/// - Commit on: Enter, Tab, click away
/// - Cancel on: Escape
///
/// Notifies listeners when edit state changes.
class EditController extends ChangeNotifier {
  /// Date parser for type detection. Set by [Worksheet] when provided.
  AnyDate? dateParser;

  /// Locale for date format detection. Set by [Worksheet] when provided.
  FormatLocale locale = FormatLocale.enUs;

  /// Callback registered by the overlay to extract rich text spans from the
  /// active editing controller. Used by external commit paths (e.g. click-away)
  /// that don't go through the overlay's own `_commit()` method.
  List<TextSpan>? Function()? richTextExtractor;

  /// The active rich text editing controller, registered by [CellEditorOverlay]
  /// during editing and cleared on dispose.
  ///
  /// Enables toolbar buttons and other external code to invoke formatting
  /// operations (bold, italic, etc.) and query the current selection style.
  RichTextEditingController? richTextController;

  /// The editor's focus node, registered by [CellEditorOverlay] during editing
  /// and cleared on dispose. Used by [requestEditorFocus] to restore focus
  /// after toolbar actions steal it.
  FocusNode? editorFocusNode;

  /// The formula bar's focus node, registered by [FormulaBar] on attach.
  ///
  /// When this node has focus, [CellEditorOverlay] skips its post-frame focus
  /// request so the formula bar retains focus during formula-bar-initiated edits.
  FocusNode? formulaBarFocusNode;

  /// Called by [Worksheet] to commit an integrated edit from an external input
  /// surface such as [FormulaBar].
  VoidCallback? externalCommitHandler;

  /// Called by [Worksheet] to cancel an integrated edit from an external input
  /// surface such as [FormulaBar].
  VoidCallback? externalCancelHandler;

  EditState _state = EditState.idle;
  CellCoordinate? _editingCell;
  CellValue? _originalValue;
  String _currentText = '';
  EditTrigger? _trigger;
  Offset? _tapPosition;

  // -- Formula bar support --

  TextEditingController? _formulaBarController;

  /// Guard flag: prevents circular sync between cell editor and formula bar.
  bool _formulaBarSyncing = false;

  /// True while the current edit session should keep focus in the formula bar.
  bool _preferFormulaBarFocus = false;

  /// Whether the most recent transition to [EditState.idle] was via [cancelEdit].
  bool _lastEditEndedWithCancel = false;

  /// The current edit state.
  EditState get state => _state;

  /// The cell currently being edited, or null if not editing.
  CellCoordinate? get editingCell => _editingCell;

  /// The original value before editing started.
  CellValue? get originalValue => _originalValue;

  /// The current text being edited.
  String get currentText => _currentText;

  /// How the current edit was triggered.
  EditTrigger? get trigger => _trigger;

  /// The screen position of the tap that initiated editing.
  ///
  /// Only set for [EditTrigger.doubleTap]. Used by the overlay to place
  /// the cursor at the tapped character position.
  Offset? get tapPosition => _tapPosition;

  /// Whether editing is currently in progress.
  bool get isEditing => _state == EditState.editing;

  /// Whether the cell currently being edited contains a formula.
  bool get isEditingFormula => _originalValue?.isFormula == true;

  /// Whether overlay focus requests should defer to the formula bar.
  bool get preferFormulaBarFocus => _preferFormulaBarFocus;

  /// Whether the last edit session ended with [cancelEdit] rather than [commitEdit].
  ///
  /// Used by [FormulaBar] to restore [FormulaBar.idleText] on cancel while keeping
  /// the committed text visible after commit.
  bool get lastEditEndedWithCancel => _lastEditEndedWithCancel;

  /// Marks the current edit session as formula-bar-focused.
  void beginFormulaBarFocusSession() {
    _preferFormulaBarFocus = true;
  }

  /// Clears the formula-bar focus preference.
  void endFormulaBarFocusSession() {
    _preferFormulaBarFocus = false;
  }

  /// Requests commit via the owning [Worksheet]'s integrated edit pathway.
  ///
  /// Falls back to [commitEdit] only when no external handler is registered.
  void requestExternalCommit({
    required void Function(
      CellCoordinate cell,
      CellValue? value, {
      CellFormat? detectedFormat,
    })
    onFallbackCommit,
  }) {
    final handler = externalCommitHandler;
    if (handler != null) {
      handler();
      return;
    }
    commitEdit(onCommit: onFallbackCommit);
  }

  /// Requests cancel via the owning [Worksheet]'s integrated edit pathway.
  void requestExternalCancel() {
    final handler = externalCancelHandler;
    if (handler != null) {
      handler();
      return;
    }
    cancelEdit();
  }

  /// Registers a [TextEditingController] as the formula bar controller.
  ///
  /// The controller will be kept in sync with the active cell editor:
  /// text and cursor position are mirrored in both directions. Registering
  /// a new controller automatically detaches the previous one.
  void attachFormulaBar(TextEditingController controller) {
    _formulaBarController?.removeListener(_onFormulaBarControllerChanged);
    _formulaBarController = controller;
    controller.addListener(_onFormulaBarControllerChanged);
    // Immediately reflect current editing state.
    _syncCurrentStateToFormulaBar();
  }

  /// Unregisters the formula bar controller previously set via [attachFormulaBar].
  void detachFormulaBar() {
    _formulaBarController?.removeListener(_onFormulaBarControllerChanged);
    _formulaBarController = null;
  }

  /// Called by [CellEditorOverlay] whenever its internal [TextEditingValue]
  /// changes (text or cursor). Pushes the value to the formula bar.
  void syncEditorValueToFormulaBar(TextEditingValue value) {
    if (_formulaBarSyncing) return;
    final fb = _formulaBarController;
    if (fb == null) return;
    _formulaBarSyncing = true;
    fb.value = value;
    _formulaBarSyncing = false;
  }

  /// Pushes the current [_currentText] (and collapsed end-cursor) to the
  /// formula bar. Called after edit start/stop.
  void _syncCurrentStateToFormulaBar() {
    final fb = _formulaBarController;
    if (fb == null) return;
    _formulaBarSyncing = true;
    if (_state != EditState.editing) {
      // Idle display is owned by [FormulaBar] (via [FormulaBar.idleText] on
      // cancel, or the last committed text on commit). Do not push empty
      // [_currentText] here — that would clear the bar after commit.
      return;
    }

    // Preserve whatever selection the overlay has already synced, or
    // default to collapsed-at-end so the bar reflects edit start.
    final currentSel = fb.selection;
    final validSel =
        currentSel.isValid &&
        currentSel.start <= _currentText.length &&
        currentSel.end <= _currentText.length;
    fb.value = TextEditingValue(
      text: _currentText,
      selection: validSel
          ? currentSel
          : TextSelection.collapsed(offset: _currentText.length),
    );
    _formulaBarSyncing = false;
  }

  /// Listener attached to [_formulaBarController]. Propagates formula bar
  /// changes back to the active cell editor.
  void _onFormulaBarControllerChanged() {
    if (_formulaBarSyncing || _state != EditState.editing) return;
    final fb = _formulaBarController;
    if (fb == null) return;

    final newText = fb.text;
    final newSel = fb.selection;

    _formulaBarSyncing = true;
    if (newText != _currentText) {
      _currentText = newText;
      // Update the overlay's RichTextEditingController so the cell editor
      // reflects the new text (plain text replaces any rich styling).
      richTextController?.value = fb.value;
      notifyListeners();
    } else {
      // Text unchanged — sync cursor/selection only.
      richTextController?.selection = newSel;
    }
    _formulaBarSyncing = false;
  }

  /// Starts editing a cell.
  ///
  /// [cell] is the cell to edit.
  /// [currentValue] is the current value of the cell.
  /// [trigger] is how the edit was initiated.
  /// [initialText] is optional initial text (for typing trigger).
  ///
  /// Returns true if editing was started successfully.
  bool startEdit({
    required CellCoordinate cell,
    CellValue? currentValue,
    EditTrigger trigger = EditTrigger.programmatic,
    String? initialText,
    Offset? tapPosition,
  }) {
    if (_state != EditState.idle) {
      return false;
    }

    _state = EditState.editing;
    _editingCell = cell;
    _originalValue = currentValue;
    _trigger = trigger;
    _tapPosition = tapPosition;

    // Set initial text
    if (initialText != null) {
      _currentText = initialText;
    } else if (trigger == EditTrigger.typing) {
      _currentText = initialText ?? '';
    } else {
      _currentText = currentValue?.displayValue ?? '';
    }

    notifyListeners();
    _syncCurrentStateToFormulaBar();
    return true;
  }

  /// Updates the current text being edited.
  ///
  /// Only valid while editing.
  void updateText(String text) {
    if (_state != EditState.editing) return;

    _currentText = text;
    notifyListeners();
  }

  /// Commits the current edit.
  ///
  /// [onCommit] is called with the cell, new value, and an optional detected
  /// format if the input was recognized as a formatted number, date, or
  /// duration.
  /// Returns the committed value, or null if commit was cancelled.
  CellValue? commitEdit({
    required void Function(
      CellCoordinate cell,
      CellValue? value, {
      CellFormat? detectedFormat,
    })
    onCommit,
  }) {
    if (_state != EditState.editing) return null;

    _lastEditEndedWithCancel = false;
    _state = EditState.committing;

    final cell = _editingCell!;
    final inputText = _currentText;

    CellValue? newValue;
    CellFormat? detectedFormat;

    // 1. Try formatted number (coupled parse + detect)
    final numberResult = NumberFormatDetector.detect(inputText, locale: locale);
    if (numberResult != null) {
      newValue = numberResult.value;
      detectedFormat = numberResult.format;
    } else {
      // 2. Standard parse (formula, boolean, plain number, duration, date, text)
      newValue = _parseText(inputText);

      if (newValue != null && newValue.isDate) {
        detectedFormat = DateFormatDetector.detect(
          inputText,
          newValue.asDateTime,
          dayFirst: locale.dayFirst,
          locale: locale,
        );
      } else if (newValue != null && newValue.isDuration) {
        detectedFormat = DurationFormatDetector.detect(
          inputText,
          newValue.asDuration,
        );
      }
    }

    // Call commit callback
    onCommit(cell, newValue, detectedFormat: detectedFormat);

    // Reset state
    _state = EditState.idle;
    _editingCell = null;
    _originalValue = null;
    _currentText = '';
    _trigger = null;
    _tapPosition = null;

    notifyListeners();
    _syncCurrentStateToFormulaBar();
    return newValue;
  }

  /// Cancels the current edit.
  ///
  /// Reverts to the original value.
  void cancelEdit() {
    if (_state != EditState.editing) return;

    _lastEditEndedWithCancel = true;
    _state = EditState.idle;
    _editingCell = null;
    _originalValue = null;
    _currentText = '';
    _trigger = null;
    _tapPosition = null;
    _preferFormulaBarFocus = false;

    notifyListeners();
    _syncCurrentStateToFormulaBar();
  }

  /// Parses text into a cell value.
  ///
  /// Delegates to [CellValue.parse] for unified type detection.
  CellValue? _parseText(String text) =>
      CellValue.parse(text, dateParser: dateParser);

  /// Checks if the current value has changed from the original.
  bool get hasChanges {
    if (_state != EditState.editing) return false;

    final newValue = _parseText(_currentText);
    if (_originalValue == null && newValue == null) return false;
    if (_originalValue == null || newValue == null) return true;

    return _originalValue != newValue;
  }

  // -- Formula reference editing --

  /// The index of the reference being actively manipulated (by pointer or
  /// keyboard). `-1` means no active reference.
  int activeReferenceIndex = -1;

  /// Whether the current edit is in formula mode.
  ///
  /// Returns `true` when editing is in progress, [config] is non-null, and
  /// the current text is recognized as a formula by the config.
  bool isFormulaMode(FormulaReferenceConfig? config) {
    if (config == null || !isEditing) return false;
    return config.isFormulaMode(_currentText);
  }

  /// Inserts [text] at the current cursor position in the rich text
  /// controller and updates [_currentText].
  ///
  /// No-op if not editing or no rich text controller is registered.
  void insertAtCursor(String text) {
    final controller = richTextController;
    if (!isEditing || controller == null) return;

    final sel = controller.selection;
    final before = controller.text.substring(0, sel.start);
    final after = controller.text.substring(sel.end);
    final newText = '$before$text$after';
    final newOffset = sel.start + text.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    updateText(newText);
  }

  // -- Rich text formatting convenience methods --
  // These delegate to [richTextController] for use by toolbars and other
  // external code that doesn't have direct access to the overlay.

  /// Toggles bold on the active editing selection. No-op if not editing.
  void toggleBold() => richTextController?.toggleBold();

  /// Toggles italic on the active editing selection. No-op if not editing.
  void toggleItalic() => richTextController?.toggleItalic();

  /// Toggles underline on the active editing selection. No-op if not editing.
  void toggleUnderline() => richTextController?.toggleUnderline();

  /// Toggles strikethrough on the active editing selection. No-op if not editing.
  void toggleStrikethrough() => richTextController?.toggleStrikethrough();

  /// Returns the common [TextStyle] across the current editing selection.
  ///
  /// Returns null when not editing or no rich text controller is active.
  TextStyle? getSelectionStyle() => richTextController?.getSelectionStyle();

  /// Whether all characters in the editing selection are bold.
  bool get isSelectionBold => richTextController?.isSelectionBold ?? false;

  /// Whether all characters in the editing selection are italic.
  bool get isSelectionItalic => richTextController?.isSelectionItalic ?? false;

  /// Whether all characters in the editing selection are underlined.
  bool get isSelectionUnderline =>
      richTextController?.isSelectionUnderline ?? false;

  /// Whether all characters in the editing selection have strikethrough.
  bool get isSelectionStrikethrough =>
      richTextController?.isSelectionStrikethrough ?? false;

  /// Requests focus on the editor overlay.
  ///
  /// Call this after toolbar actions that may steal focus from the editor
  /// (e.g. clicking an [IconButton] while editing). Schedules focus
  /// restoration via a post-frame callback so it runs after the current
  /// build phase completes.
  void requestEditorFocus() {
    final node = editorFocusNode;
    if (node == null || !isEditing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isEditing && !node.hasFocus && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }
}
