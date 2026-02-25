import '../core/data/formula_reference_adjuster.dart';
import '../core/data/worksheet_data.dart';
import '../core/geometry/layout_solver.dart';
import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import '../interaction/clipboard/clipboard_handler.dart';
import '../interaction/controllers/edit_controller.dart';
import '../interaction/controllers/selection_controller.dart';
import '../interaction/undo/undo_entry.dart';
import '../interaction/undo/undo_manager.dart';
import '../interaction/undo/undo_snapshot.dart';

/// Interface providing the dependencies that worksheet [Action] classes need.
///
/// Implemented by the worksheet widget's state to avoid threading many
/// constructor parameters into every Action.
abstract mixin class WorksheetActionContext {
  /// The selection controller for reading and updating selection state.
  SelectionController get selectionController;

  /// Maximum row count (exclusive) for clamping.
  int get maxRow;

  /// Maximum column count (exclusive) for clamping.
  int get maxColumn;

  /// The worksheet data source for cell operations.
  WorksheetData get worksheetData;

  /// The clipboard handler for copy/cut/paste.
  ClipboardHandler get clipboardHandler;

  /// Whether the worksheet is in read-only mode.
  bool get readOnly;

  /// Callback to enter edit mode on a cell, or null if editing is disabled.
  void Function(CellCoordinate)? get onEditCell;

  /// Scrolls to ensure the currently focused cell is visible.
  void ensureSelectionVisible();

  /// Invalidates tiles and triggers a rebuild of the widget.
  void invalidateAndRebuild();

  /// The edit controller, or null if editing is managed externally.
  EditController? get editController => null;

  /// The formula reference adjuster for fill operations, or null to copy
  /// formulas verbatim. Defaults to [defaultFormulaReferenceAdjuster].
  FormulaReferenceAdjuster? get formulaReferenceAdjuster =>
      defaultFormulaReferenceAdjuster;

  /// The cell range marked for a deferred cut (marching ants), or null.
  CellRange? get pendingCutRange => null;

  /// Sets or clears the pending cut range.
  ///
  /// When [range] is non-null, starts marching ants animation.
  /// When null, stops animation and clears the indicator.
  void setPendingCutRange(CellRange? range) {}

  /// The layout solver for row/column sizes, or null if not available.
  LayoutSolver? get layoutSolver => null;

  /// The undo manager, or null if undo is not enabled.
  UndoManager? get undoManager => null;

  /// Records an undoable operation.
  ///
  /// Captures cell state and merges within [affectedRange] before [mutation],
  /// executes the mutation, captures the after state, and pushes an
  /// [UndoEntry] onto the undo stack.
  ///
  /// If [undoManager] is null, simply executes [mutation] without recording.
  void recordUndo(
    String label,
    CellRange affectedRange,
    void Function() mutation,
  ) {
    final um = undoManager;
    if (um == null) {
      mutation();
      return;
    }
    final selBefore = (
      selectionController.anchor,
      selectionController.focus,
    );
    final (cellsBefore, mergesBefore) =
        UndoSnapshot.capture(worksheetData, affectedRange);

    mutation();

    final selAfter = (
      selectionController.anchor,
      selectionController.focus,
    );
    final (cellsAfter, mergesAfter) =
        UndoSnapshot.capture(worksheetData, affectedRange);

    um.push(UndoEntry(
      label: label,
      affectedRange: affectedRange,
      cellsBefore: cellsBefore,
      mergesBefore: mergesBefore,
      selectionBefore: selBefore,
      cellsAfter: cellsAfter,
      mergesAfter: mergesAfter,
      selectionAfter: selAfter,
    ));
  }

  /// Performs an undo operation: restores the before-state of the most
  /// recent entry and restores the before-selection.
  void performUndo() {
    final um = undoManager;
    if (um == null || !um.canUndo) return;
    final entry = um.undo();
    if (entry == null) return;

    // Only restore cells/merges when the entry has cell data.
    // Resize-only entries have empty cells and merges.
    final hasCellData = entry.cellsBefore.isNotEmpty ||
        entry.mergesBefore.isNotEmpty ||
        entry.cellsAfter.isNotEmpty ||
        entry.mergesAfter.isNotEmpty;
    if (hasCellData) {
      UndoSnapshot.restore(
        worksheetData,
        entry.affectedRange,
        entry.cellsBefore,
        entry.mergesBefore,
      );
    }

    final solver = layoutSolver;
    if (solver != null) {
      entry.rowSizesBefore?.forEach(solver.setRowHeight);
      entry.columnSizesBefore?.forEach(solver.setColumnWidth);
      if (entry.rowSizesBefore != null || entry.columnSizesBefore != null) {
        invalidateAndRebuild();
      }
    }

    final (anchor, focus) = entry.selectionBefore;
    if (anchor != null && focus != null) {
      selectionController.selectCell(anchor);
      if (anchor != focus) {
        selectionController.extendSelection(focus);
      }
    }
  }

  /// Performs a redo operation: restores the after-state of the most
  /// recent undone entry and restores the after-selection.
  void performRedo() {
    final um = undoManager;
    if (um == null || !um.canRedo) return;
    final entry = um.redo();
    if (entry == null) return;

    final hasCellData = entry.cellsBefore.isNotEmpty ||
        entry.mergesBefore.isNotEmpty ||
        entry.cellsAfter.isNotEmpty ||
        entry.mergesAfter.isNotEmpty;
    if (hasCellData) {
      UndoSnapshot.restore(
        worksheetData,
        entry.affectedRange,
        entry.cellsAfter,
        entry.mergesAfter,
      );
    }

    final solver = layoutSolver;
    if (solver != null) {
      entry.rowSizesAfter?.forEach(solver.setRowHeight);
      entry.columnSizesAfter?.forEach(solver.setColumnWidth);
      if (entry.rowSizesAfter != null || entry.columnSizesAfter != null) {
        invalidateAndRebuild();
      }
    }

    final (anchor, focus) = entry.selectionAfter;
    if (anchor != null && focus != null) {
      selectionController.selectCell(anchor);
      if (anchor != focus) {
        selectionController.extendSelection(focus);
      }
    }
  }
}
