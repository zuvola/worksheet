import 'package:flutter/widgets.dart';

import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import '../core/models/cell_style.dart';
import '../core/models/cell_value.dart';
import 'worksheet_action_context.dart';
import 'worksheet_intents.dart';

/// Moves the selection focus by a row/column delta.
///
/// Handles arrow keys, page up/down, tab, and enter navigation.
class MoveSelectionAction extends Action<MoveSelectionIntent> {
  final WorksheetActionContext _context;

  MoveSelectionAction(this._context);

  @override
  bool isEnabled(MoveSelectionIntent intent) =>
      _context.editController?.isEditing != true;

  @override
  Object? invoke(MoveSelectionIntent intent) {
    _context.selectionController.moveFocus(
      rowDelta: intent.rowDelta,
      columnDelta: intent.columnDelta,
      extend: intent.extend,
      maxRow: _context.maxRow,
      maxColumn: _context.maxColumn,
    );
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Navigates to a specific cell coordinate.
class GoToCellAction extends Action<GoToCellIntent> {
  final WorksheetActionContext _context;

  GoToCellAction(this._context);

  @override
  Object? invoke(GoToCellIntent intent) {
    _context.selectionController.selectCell(intent.coordinate);
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Navigates to the last cell in the worksheet.
class GoToLastCellAction extends Action<GoToLastCellIntent> {
  final WorksheetActionContext _context;

  GoToLastCellAction(this._context);

  @override
  Object? invoke(GoToLastCellIntent intent) {
    _context.selectionController.selectCell(
      CellCoordinate(_context.maxRow - 1, _context.maxColumn - 1),
    );
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Navigates to the start or end of the current row.
class GoToRowBoundaryAction extends Action<GoToRowBoundaryIntent> {
  final WorksheetActionContext _context;

  GoToRowBoundaryAction(this._context);

  @override
  Object? invoke(GoToRowBoundaryIntent intent) {
    final focus = _context.selectionController.focus;
    if (focus == null) return null;

    final targetColumn = intent.end ? _context.maxColumn - 1 : 0;
    final target = CellCoordinate(focus.row, targetColumn);

    if (intent.extend) {
      _context.selectionController.extendSelection(target);
    } else {
      _context.selectionController.selectCell(target);
    }
    _context.ensureSelectionVisible();
    return null;
  }
}

/// Selects all cells in the worksheet.
class SelectAllCellsAction extends Action<SelectAllCellsIntent> {
  final WorksheetActionContext _context;

  SelectAllCellsAction(this._context);

  @override
  bool isEnabled(SelectAllCellsIntent intent) =>
      _context.editController?.isEditing != true;

  @override
  Object? invoke(SelectAllCellsIntent intent) {
    _context.selectionController.selectRange(
      CellRange(0, 0, _context.maxRow - 1, _context.maxColumn - 1),
    );
    return null;
  }
}

/// Cancels the current selection extension, collapsing to the focus cell.
class CancelSelectionAction extends Action<CancelSelectionIntent> {
  final WorksheetActionContext _context;

  CancelSelectionAction(this._context);

  @override
  Object? invoke(CancelSelectionIntent intent) {
    final focus = _context.selectionController.focus;
    if (focus != null) {
      _context.selectionController.selectCell(focus);
    }
    return null;
  }
}

/// Enters edit mode on the currently focused cell.
class EditCellAction extends Action<EditCellIntent> {
  final WorksheetActionContext _context;

  EditCellAction(this._context);

  @override
  Object? invoke(EditCellIntent intent) {
    final focus = _context.selectionController.focus;
    if (focus != null) {
      _context.onEditCell?.call(focus);
    }
    return null;
  }
}

/// Copies the selected cells to the system clipboard.
class CopyCellsAction extends Action<CopyCellsIntent> {
  final WorksheetActionContext _context;

  CopyCellsAction(this._context);

  @override
  bool isEnabled(CopyCellsIntent intent) =>
      _context.editController?.isEditing != true;

  @override
  Object? invoke(CopyCellsIntent intent) {
    _context.clipboardHandler.copy();
    return null;
  }
}

/// Cuts the selected cells to the system clipboard.
class CutCellsAction extends Action<CutCellsIntent> {
  final WorksheetActionContext _context;

  CutCellsAction(this._context);

  @override
  bool isEnabled(CutCellsIntent intent) =>
      !_context.readOnly && _context.editController?.isEditing != true;

  @override
  Object? invoke(CutCellsIntent intent) {
    _context.clipboardHandler.cut().then((_) {
      _context.invalidateAndRebuild();
    });
    return null;
  }
}

/// Pastes from the system clipboard at the current selection.
class PasteCellsAction extends Action<PasteCellsIntent> {
  final WorksheetActionContext _context;

  PasteCellsAction(this._context);

  @override
  bool isEnabled(PasteCellsIntent intent) =>
      !_context.readOnly && _context.editController?.isEditing != true;

  @override
  Object? invoke(PasteCellsIntent intent) {
    _context.clipboardHandler.paste().then((_) {
      _context.invalidateAndRebuild();
    });
    return null;
  }
}

/// Clears the contents of the selected cells.
class ClearCellsAction extends Action<ClearCellsIntent> {
  final WorksheetActionContext _context;

  ClearCellsAction(this._context);

  @override
  bool isEnabled(ClearCellsIntent intent) {
    if (_context.readOnly) return false;
    // When editing, only allow clearing styles/formats (toolbar use).
    // Block clearing values so Backspace/Delete are handled by the text editor.
    if (_context.editController?.isEditing == true && intent.clearValue) {
      return false;
    }
    return true;
  }

  @override
  Object? invoke(ClearCellsIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null) return null;

    if (intent.clearValue && intent.clearStyle && intent.clearFormat) {
      _context.worksheetData.clearRange(range);
    } else {
      _context.worksheetData.batchUpdate((batch) {
        if (intent.clearValue) batch.clearValues(range);
        if (intent.clearStyle) batch.clearStyles(range);
        if (intent.clearFormat) batch.clearFormats(range);
      });
    }

    // Unmerge cells when clearing formatting (styles or formats).
    if (intent.clearStyle || intent.clearFormat) {
      _context.worksheetData.unmergeCellsInRange(range);
    }

    // Strip rich text formatting when clearing styles.
    if (intent.clearStyle) {
      if (_context.editController?.isEditing == true) {
        _context.editController?.richTextController?.clearFormatting();
      } else {
        _context.worksheetData.clearRichTextInRange(range);
      }
    }

    _context.invalidateAndRebuild();
    return null;
  }
}

/// Fills the selected range downward from the first row.
class FillDownAction extends Action<FillDownIntent> {
  final WorksheetActionContext _context;

  FillDownAction(this._context);

  @override
  bool isEnabled(FillDownIntent intent) => !_context.readOnly;

  @override
  Object? invoke(FillDownIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.rowCount < 2) return null;
    final adjuster = _context.formulaReferenceAdjuster;
    for (int col = range.startColumn; col <= range.endColumn; col++) {
      final source = CellCoordinate(range.startRow, col);
      final target = CellRange(range.startRow + 1, col, range.endRow, col);
      if (adjuster != null) {
        _context.worksheetData.fillRange(source, target, (coord, sourceCell) {
          if (sourceCell == null) return null;
          final value = sourceCell.value;
          if (value == null || !value.isFormula) return sourceCell;
          final rowDelta = coord.row - source.row;
          final adjusted = adjuster(value.rawValue as String, rowDelta, 0);
          return sourceCell.copyWithValue(CellValue.formula(adjusted));
        });
      } else {
        _context.worksheetData.fillRange(source, target);
      }
    }
    _context.worksheetData.replicateMerges(
      sourceRange: CellRange(
        range.startRow, range.startColumn,
        range.startRow, range.endColumn,
      ),
      targetRange: CellRange(
        range.startRow + 1, range.startColumn,
        range.endRow, range.endColumn,
      ),
      vertical: true,
    );
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Fills the selected range rightward from the first column.
class FillRightAction extends Action<FillRightIntent> {
  final WorksheetActionContext _context;

  FillRightAction(this._context);

  @override
  bool isEnabled(FillRightIntent intent) => !_context.readOnly;

  @override
  Object? invoke(FillRightIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.columnCount < 2) return null;
    final adjuster = _context.formulaReferenceAdjuster;
    for (int row = range.startRow; row <= range.endRow; row++) {
      final source = CellCoordinate(row, range.startColumn);
      final target = CellRange(row, range.startColumn + 1, row, range.endColumn);
      if (adjuster != null) {
        _context.worksheetData.fillRange(source, target, (coord, sourceCell) {
          if (sourceCell == null) return null;
          final value = sourceCell.value;
          if (value == null || !value.isFormula) return sourceCell;
          final colDelta = coord.column - source.column;
          final adjusted = adjuster(value.rawValue as String, 0, colDelta);
          return sourceCell.copyWithValue(CellValue.formula(adjusted));
        });
      } else {
        _context.worksheetData.fillRange(source, target);
      }
    }
    _context.worksheetData.replicateMerges(
      sourceRange: CellRange(
        range.startRow, range.startColumn,
        range.endRow, range.startColumn,
      ),
      targetRange: CellRange(
        range.startRow, range.startColumn + 1,
        range.endRow, range.endColumn,
      ),
      vertical: false,
    );
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Merges all cells in the current selection into a single merged cell.
class MergeCellsAction extends Action<MergeCellsIntent> {
  final WorksheetActionContext _context;

  MergeCellsAction(this._context);

  @override
  bool isEnabled(MergeCellsIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    return range != null && range.cellCount >= 2;
  }

  @override
  Object? invoke(MergeCellsIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.cellCount < 2) return null;

    _context.worksheetData.mergeCells(range);
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Merges each row of the current selection separately.
class MergeCellsHorizontallyAction extends Action<MergeCellsHorizontallyIntent> {
  final WorksheetActionContext _context;

  MergeCellsHorizontallyAction(this._context);

  @override
  bool isEnabled(MergeCellsHorizontallyIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    return range != null && range.columnCount >= 2;
  }

  @override
  Object? invoke(MergeCellsHorizontallyIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.columnCount < 2) return null;

    for (int row = range.startRow; row <= range.endRow; row++) {
      _context.worksheetData.mergeCells(
        CellRange(row, range.startColumn, row, range.endColumn),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Merges each column of the current selection separately.
class MergeCellsVerticallyAction extends Action<MergeCellsVerticallyIntent> {
  final WorksheetActionContext _context;

  MergeCellsVerticallyAction(this._context);

  @override
  bool isEnabled(MergeCellsVerticallyIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    return range != null && range.rowCount >= 2;
  }

  @override
  Object? invoke(MergeCellsVerticallyIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null || range.rowCount < 2) return null;

    for (int col = range.startColumn; col <= range.endColumn; col++) {
      _context.worksheetData.mergeCells(
        CellRange(range.startRow, col, range.endRow, col),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Toggles bold formatting on the current text selection or all selected cells.
///
/// When editing: toggles bold on the text selection via [RichTextEditingController].
/// When not editing: toggles bold on rich text spans for all selected cells.
class ToggleBoldAction extends Action<ToggleBoldIntent> {
  final WorksheetActionContext _context;

  ToggleBoldAction(this._context);

  @override
  bool isEnabled(ToggleBoldIntent intent) {
    if (_context.readOnly) return false;
    if (_context.editController?.isEditing == true) {
      return _context.editController?.richTextController != null;
    }
    return _context.selectionController.selectedRange != null;
  }

  @override
  Object? invoke(ToggleBoldIntent intent) {
    if (_context.editController?.isEditing == true) {
      _context.editController!.richTextController!.toggleBold();
    } else {
      _toggleOnSelection(
        _context,
        test: (s) => s?.fontWeight == FontWeight.bold,
        apply: (s) =>
            (s ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold),
        remove: (s) =>
            (s ?? const TextStyle()).copyWith(fontWeight: FontWeight.normal),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Toggles italic formatting on the current text selection or all selected cells.
class ToggleItalicAction extends Action<ToggleItalicIntent> {
  final WorksheetActionContext _context;

  ToggleItalicAction(this._context);

  @override
  bool isEnabled(ToggleItalicIntent intent) {
    if (_context.readOnly) return false;
    if (_context.editController?.isEditing == true) {
      return _context.editController?.richTextController != null;
    }
    return _context.selectionController.selectedRange != null;
  }

  @override
  Object? invoke(ToggleItalicIntent intent) {
    if (_context.editController?.isEditing == true) {
      _context.editController!.richTextController!.toggleItalic();
    } else {
      _toggleOnSelection(
        _context,
        test: (s) => s?.fontStyle == FontStyle.italic,
        apply: (s) =>
            (s ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic),
        remove: (s) =>
            (s ?? const TextStyle()).copyWith(fontStyle: FontStyle.normal),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Toggles underline formatting on the current text selection or all selected cells.
class ToggleUnderlineAction extends Action<ToggleUnderlineIntent> {
  final WorksheetActionContext _context;

  ToggleUnderlineAction(this._context);

  @override
  bool isEnabled(ToggleUnderlineIntent intent) {
    if (_context.readOnly) return false;
    if (_context.editController?.isEditing == true) {
      return _context.editController?.richTextController != null;
    }
    return _context.selectionController.selectedRange != null;
  }

  @override
  Object? invoke(ToggleUnderlineIntent intent) {
    if (_context.editController?.isEditing == true) {
      _context.editController!.richTextController!.toggleUnderline();
    } else {
      _toggleOnSelection(
        _context,
        test: (s) => s?.decoration == TextDecoration.underline,
        apply: (s) => (s ?? const TextStyle())
            .copyWith(decoration: TextDecoration.underline),
        remove: (s) =>
            (s ?? const TextStyle()).copyWith(decoration: TextDecoration.none),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Toggles strikethrough formatting on the current text selection or all selected cells.
class ToggleStrikethroughAction extends Action<ToggleStrikethroughIntent> {
  final WorksheetActionContext _context;

  ToggleStrikethroughAction(this._context);

  @override
  bool isEnabled(ToggleStrikethroughIntent intent) {
    if (_context.readOnly) return false;
    if (_context.editController?.isEditing == true) {
      return _context.editController?.richTextController != null;
    }
    return _context.selectionController.selectedRange != null;
  }

  @override
  Object? invoke(ToggleStrikethroughIntent intent) {
    if (_context.editController?.isEditing == true) {
      _context.editController!.richTextController!.toggleStrikethrough();
    } else {
      _toggleOnSelection(
        _context,
        test: (s) => s?.decoration == TextDecoration.lineThrough,
        apply: (s) => (s ?? const TextStyle())
            .copyWith(decoration: TextDecoration.lineThrough),
        remove: (s) =>
            (s ?? const TextStyle()).copyWith(decoration: TextDecoration.none),
      );
    }
    _context.invalidateAndRebuild();
    return null;
  }
}

/// Toggles a text style property on all rich text spans in the selected cells.
///
/// If all spans across all selected cells match [test], [remove] is applied;
/// otherwise [apply] is applied to all spans.
///
/// Uses sparse iteration: only visits cells that have rich text or values,
/// so this is O(populated_cells) not O(range_area).
void _toggleOnSelection(
  WorksheetActionContext context, {
  required bool Function(TextStyle?) test,
  required TextStyle Function(TextStyle?) apply,
  required TextStyle Function(TextStyle?) remove,
}) {
  final range = context.selectionController.selectedRange;
  if (range == null) return;

  // Collect all (coord, spans) pairs from populated cells only.
  // Cells with explicit rich text come from getRichTextInRange;
  // cells with only a value (no rich text) get auto-spans.
  final entries = <MapEntry<CellCoordinate, List<TextSpan>>>[];
  final richTextCoords = <CellCoordinate>{};

  for (final entry in context.worksheetData.getRichTextInRange(range)) {
    if (entry.value.isNotEmpty) {
      entries.add(entry);
      richTextCoords.add(entry.key);
    }
  }

  // Also include cells that have values but no rich text (auto-span).
  for (final entry in context.worksheetData.getCellsInRange(range)) {
    if (!richTextCoords.contains(entry.key)) {
      final autoSpans = [TextSpan(text: entry.value.displayValue)];
      entries.add(MapEntry(entry.key, autoSpans));
    }
  }

  if (entries.isEmpty) return;

  // Check if ALL spans across ALL populated cells match
  final allMatch = entries.every(
    (e) => e.value.isNotEmpty && e.value.every((s) => test(s.style)),
  );

  // Apply or remove across populated cells only
  for (final entry in entries) {
    final spans = entry.value;
    if (spans.isEmpty) continue;
    final toggled = spans
        .map((s) => TextSpan(
              text: s.text,
              style: allMatch ? remove(s.style) : apply(s.style),
            ))
        .toList();
    context.worksheetData.setRichText(entry.key, toggled);
  }
}

/// Unmerges all merge regions overlapping the current selection.
class UnmergeCellsAction extends Action<UnmergeCellsIntent> {
  final WorksheetActionContext _context;

  UnmergeCellsAction(this._context);

  @override
  bool isEnabled(UnmergeCellsIntent intent) {
    if (_context.readOnly) return false;
    final range = _context.selectionController.selectedRange;
    if (range == null) return false;
    final mergedCells = _context.worksheetData.mergedCells;
    return mergedCells.regionsInRange(range).isNotEmpty;
  }

  @override
  Object? invoke(UnmergeCellsIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null) return null;

    _context.worksheetData.unmergeCellsInRange(range);

    _context.invalidateAndRebuild();
    return null;
  }
}

/// Applies a [CellStyle] to the selected cells by merging it into each
/// cell's existing style.
///
/// Works during and outside editing — no `isEditing` guard. Only non-null
/// fields in the intent's style override existing values.
class SetCellStyleAction extends Action<SetCellStyleIntent> {
  final WorksheetActionContext _context;

  SetCellStyleAction(this._context);

  @override
  bool isEnabled(SetCellStyleIntent intent) => !_context.readOnly;

  @override
  Object? invoke(SetCellStyleIntent intent) {
    final range = _context.selectionController.selectedRange;
    if (range == null) return null;

    // Pre-compute a border-stripped copy so non-anchor merge cells
    // don't get borders stored in the data model.
    final hasBorders = intent.style.borders != null;
    final noBordersStyle = hasBorders
        ? CellStyle(
            backgroundColor: intent.style.backgroundColor,
            textAlignment: intent.style.textAlignment,
            verticalAlignment: intent.style.verticalAlignment,
            wrapText: intent.style.wrapText,
          )
        : null;

    // For large ranges, iterate only populated cells (sparse path).
    if (range.cellCount > 1000000) {
      _applyStyleSparse(range, intent.style, hasBorders, noBordersStyle);
    } else {
      for (int row = range.startRow; row <= range.endRow; row++) {
        for (int col = range.startColumn; col <= range.endColumn; col++) {
          final coord = CellCoordinate(row, col);
          _applyStyleToCell(coord, intent.style, hasBorders, noBordersStyle);
        }
      }
    }

    _context.invalidateAndRebuild();
    return null;
  }

  void _applyStyleToCell(
    CellCoordinate coord,
    CellStyle style,
    bool hasBorders,
    CellStyle? noBordersStyle,
  ) {
    var styleToApply = style;
    if (hasBorders) {
      final region = _context.worksheetData.mergedCells.getRegion(coord);
      if (region != null && !region.isAnchor(coord)) {
        styleToApply = noBordersStyle!;
      }
    }
    final current = _context.worksheetData.getStyle(coord);
    final merged = current != null ? current.merge(styleToApply) : styleToApply;
    _context.worksheetData.setStyle(coord, merged);
  }

  void _applyStyleSparse(
    CellRange range,
    CellStyle style,
    bool hasBorders,
    CellStyle? noBordersStyle,
  ) {
    final visited = <CellCoordinate>{};

    // Apply to cells that already have styles
    for (final entry in _context.worksheetData.getStylesInRange(range)) {
      _applyStyleToCell(entry.key, style, hasBorders, noBordersStyle);
      visited.add(entry.key);
    }

    // Apply to cells that have values but no style yet
    for (final entry in _context.worksheetData.getCellsInRange(range)) {
      if (!visited.contains(entry.key)) {
        _applyStyleToCell(entry.key, style, hasBorders, noBordersStyle);
      }
    }
  }
}
