import 'package:flutter/services.dart';

import 'dart:math' as math;

import '../../core/core.dart';
import '../controllers/selection_controller.dart';
import 'clipboard_serializer.dart';

/// Orchestrates clipboard operations (copy, cut, paste) for a worksheet.
///
/// Uses [ClipboardSerializer] to convert between cell data and clipboard text.
/// Interacts with the system clipboard via [Clipboard].
class ClipboardHandler {
  /// The worksheet data source.
  final WorksheetData data;

  /// The selection controller providing the selected range.
  final SelectionController selectionController;

  /// The serializer for clipboard text conversion.
  final ClipboardSerializer serializer;

  ClipboardHandler({
    required this.data,
    required this.selectionController,
    required this.serializer,
  });

  /// Copies the selected cells to the system clipboard as text.
  ///
  /// Does nothing if no range is selected.
  Future<void> copy() async {
    final range = selectionController.selectedRange;
    if (range == null) return;
    final text = serializer.serialize(range, data);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Copies the selected cells to the clipboard for a deferred cut.
  ///
  /// Unlike the old immediate-delete behavior, this only copies to the
  /// clipboard and returns the cut range. The caller is responsible for
  /// showing marching ants and completing the cut on paste.
  ///
  /// Returns the cut range, or null if no range is selected.
  Future<CellRange?> cut() async {
    final range = selectionController.selectedRange;
    if (range == null) return null;
    final text = serializer.serialize(range, data);
    await Clipboard.setData(ClipboardData(text: text));
    return range;
  }

  /// Completes a deferred cut by clearing the source cells.
  ///
  /// Called by the paste action after pasting, to remove the original data.
  /// If [recordUndo] is provided, the clear is wrapped for undo.
  void completeCut(
    CellRange range, {
    void Function(String label, CellRange range, void Function() mutation)?
        recordUndo,
  }) {
    if (recordUndo != null) {
      recordUndo('Cut', range, () => data.clearRange(range));
    } else {
      data.clearRange(range);
    }
  }

  /// Pastes from the system clipboard at the selection anchor.
  ///
  /// Parses the clipboard text into cell values and writes them into the
  /// worksheet starting at the top-left of the current selection.
  /// Values are clamped to worksheet bounds.
  ///
  /// When [pendingCutRange] is provided (deferred cut), the paste and source
  /// clear are combined into a single undo entry whose affected range is the
  /// bounding box of both the paste destination and the cut source.
  ///
  /// Does nothing if no range is selected or clipboard is empty.
  /// If [recordUndo] is provided, the synchronous write is wrapped for undo.
  Future<void> paste({
    void Function(String label, CellRange range, void Function() mutation)?
        recordUndo,
    CellRange? pendingCutRange,
  }) async {
    final range = selectionController.selectedRange;
    if (range == null) return;
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipData?.text == null || clipData!.text!.isEmpty) return;
    final grid = serializer.deserialize(clipData.text!);
    if (grid.isEmpty) return;
    final startRow = range.startRow;
    final startCol = range.startColumn;
    final maxPasteRows = grid.length;
    final maxPasteCols = grid.fold(0, (m, row) => math.max(m, row.length));
    final endRow = math.min(startRow + maxPasteRows - 1, data.rowCount - 1);
    final endCol = math.min(startCol + maxPasteCols - 1, data.columnCount - 1);
    final pasteRange = CellRange(startRow, startCol, endRow, endCol);
    void doWrite() {
      data.batchUpdate((batch) {
        for (int r = 0; r < grid.length; r++) {
          for (int c = 0; c < grid[r].length; c++) {
            final coord = CellCoordinate(startRow + r, startCol + c);
            if (coord.row < data.rowCount && coord.column < data.columnCount) {
              batch.setCell(coord, grid[r][c]);
            }
          }
        }
      });
      // Clear the cut source cells as part of the same mutation.
      if (pendingCutRange != null) {
        data.clearRange(pendingCutRange);
      }
      selectionController.selectRange(pasteRange);
    }
    if (recordUndo != null) {
      final affectedRange = pendingCutRange != null
          ? pasteRange.union(pendingCutRange)
          : pasteRange;
      recordUndo('Paste', affectedRange, doWrite);
    } else {
      doWrite();
    }
  }
}
