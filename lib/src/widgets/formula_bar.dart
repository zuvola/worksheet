import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
import '../interaction/interaction.dart';

/// An Excel-style formula bar that stays in sync with the active cell editor.
///
/// Place [FormulaBar] above a [Worksheet] widget to let users view and edit
/// cell content in a dedicated text field. Text and cursor position are
/// mirrored bidirectionally: typing in either the cell editor or the formula
/// bar updates both.
///
/// ## Basic usage
/// ```dart
/// Column(
///   children: [
///     FormulaBar(editController: _editController),
///     Expanded(child: Worksheet(..., editController: _editController)),
///   ],
/// )
/// ```
///
/// ## Commit / cancel behaviour
/// Pressing **Enter** or **Tab** commits the edit (identical to pressing
/// Enter in the cell editor). Pressing **Escape** cancels the edit.
/// Committing from the formula bar does not perform navigation (no row/column
/// delta); the post-commit selection stays on the current cell.
///
/// ## Readonly mode
/// When [EditController.isEditing] is false the field is disabled. Optionally
/// supply [idleText] to show a placeholder string (e.g. the selected cell's
/// display value) while no edit is in progress.
class FormulaBar extends StatefulWidget {
  /// The edit controller shared with the [Worksheet].
  final EditController editController;

  /// Text to display in the bar when no edit is in progress.
  ///
  /// Typically set to the display value of the currently selected cell.
  /// Defaults to an empty string.
  final String idleText;

  /// Text style applied to the editable content.
  ///
  /// Defaults to the ambient [TextTheme.bodyMedium] when null.
  final TextStyle? textStyle;

  /// Decoration applied to the underlying [TextField].
  ///
  /// Defaults to a subtle underline-style decoration when null.
  final InputDecoration? decoration;

  /// Focus node for the formula bar.
  ///
  /// When null a private node is created automatically.
  final FocusNode? focusNode;

  /// Creates a formula bar.
  const FormulaBar({
    super.key,
    required this.editController,
    this.idleText = '',
    this.textStyle,
    this.decoration,
    this.focusNode,
  });

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  // Whether _focusNode was created internally (must be disposed by us).
  late final bool _ownsFocusNode;

  /// True while we are pushing a change originated by the cell editor into
  /// [_controller]. Prevents [_onFormulaBarChanged] from running.
  bool _selfUpdate = false;

  @override
  void initState() {
    super.initState();

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _controller = TextEditingController(text: widget.idleText);
    _controller.addListener(_onFormulaBarChanged);
    widget.editController.addListener(_onEditControllerChanged);
    widget.editController.attachFormulaBar(_controller);
  }

  @override
  void didUpdateWidget(FormulaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editController != oldWidget.editController) {
      oldWidget.editController.removeListener(_onEditControllerChanged);
      oldWidget.editController.detachFormulaBar();
      widget.editController.addListener(_onEditControllerChanged);
      widget.editController.attachFormulaBar(_controller);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onFormulaBarChanged);
    widget.editController.removeListener(_onEditControllerChanged);
    widget.editController.detachFormulaBar();
    _controller.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Listeners
  // ---------------------------------------------------------------------------

  /// Called when [EditController] state changes (edit started/stopped).
  void _onEditControllerChanged() {
    if (!widget.editController.isEditing) {
      // Edit stopped — show idle text and drop focus.
      _selfUpdate = true;
      _controller.text = widget.idleText;
      _selfUpdate = false;
      if (_focusNode.hasFocus) {
        // Unfocus gently; the cell will manage its own focus restoration.
        _focusNode.unfocus(
          disposition: UnfocusDisposition.previouslyFocusedChild,
        );
      }
    }
    // Rebuild to reflect enabled/disabled state.
    if (mounted) setState(() {});
  }

  /// Called on every [_controller] change. Forwards text typed in the formula
  /// bar to the cell editor via [EditController].
  ///
  /// No-op when [_selfUpdate] is true (change originated from the cell editor)
  /// or when not in editing state (read-only idle display).
  void _onFormulaBarChanged() {
    // Changes caused by EditController sync are already guarded internally
    // via _formulaBarSyncing; this guard handles our own _selfUpdate assignments.
    if (_selfUpdate) return;
    // EditController._onFormulaBarControllerChanged handles the actual sync.
  }

  // ---------------------------------------------------------------------------
  // Key handling
  // ---------------------------------------------------------------------------

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!widget.editController.isEditing) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.editController.cancelEdit();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _commitFromFormulaBar();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _commitFromFormulaBar();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _commitFromFormulaBar() {
    // Rich text is preserved via the overlay's extractor when available.
    widget.editController.commitEdit(
      onCommit: (cell, value, {CellFormat? detectedFormat}) {
        // FormulaBar itself does not perform post-commit navigation.
        // The host widget's Worksheet handles selection via its own
        // EditController listener.
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editController.isEditing;

    final effectiveDecoration =
        (widget.decoration ??
                InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  enabled: isEditing,
                ))
            .copyWith(enabled: isEditing);

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: isEditing,
        style: widget.textStyle,
        decoration: effectiveDecoration,
        // Single-line input; Enter / Escape handled via onKeyEvent above.
        maxLines: 1,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
      ),
    );
  }
}
