import 'package:worksheet/src/core/data/formula_reference_adjuster.dart';
import 'package:worksheet/src/core/data/worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_handler.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/shortcuts/worksheet_action_context.dart';

class MockWorksheetActionContext implements WorksheetActionContext {
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
  });

  @override
  void ensureSelectionVisible() {
    ensureSelectionVisibleCount++;
  }

  @override
  void invalidateAndRebuild() {
    invalidateAndRebuildCount++;
  }
}
