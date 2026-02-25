import 'package:worksheet/src/core/data/formula_reference_adjuster.dart';
import 'package:worksheet/src/core/data/worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_handler.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/interaction/undo/undo_manager.dart';
import 'package:worksheet/src/shortcuts/worksheet_action_context.dart';

class MockWorksheetActionContext extends WorksheetActionContext {
  @override
  final SelectionController selectionController;
  @override
  final int maxRow;
  @override
  final int maxColumn;
  @override
  final WorksheetData worksheetData;
  @override
  final ClipboardHandler clipboardHandler;
  @override
  final bool readOnly;
  @override
  final void Function(CellCoordinate)? onEditCell;
  @override
  final EditController? editController;
  @override
  FormulaReferenceAdjuster? formulaReferenceAdjuster =
      defaultFormulaReferenceAdjuster;
  @override
  LayoutSolver? layoutSolver;
  @override
  UndoManager? undoManager;

  @override
  CellRange? pendingCutRange;

  int ensureSelectionVisibleCount = 0;
  int invalidateAndRebuildCount = 0;

  MockWorksheetActionContext({
    required this.selectionController,
    required this.maxRow,
    required this.maxColumn,
    required this.worksheetData,
    required this.clipboardHandler,
    this.readOnly = false,
    this.onEditCell,
    this.editController,
    this.formulaReferenceAdjuster = defaultFormulaReferenceAdjuster,
    this.layoutSolver,
    this.undoManager,
  });

  @override
  void ensureSelectionVisible() {
    ensureSelectionVisibleCount++;
  }

  @override
  void invalidateAndRebuild() {
    invalidateAndRebuildCount++;
  }

  @override
  void setPendingCutRange(CellRange? range) {
    pendingCutRange = range;
  }
}
