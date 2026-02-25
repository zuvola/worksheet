import 'package:worksheet/src/core/core.dart';
import 'package:worksheet/src/interaction/interaction.dart';
import 'package:worksheet/src/shortcuts/shortcuts.dart';

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
