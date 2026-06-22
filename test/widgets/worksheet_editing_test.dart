import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/delegating_worksheet_data.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/data/worksheet_data.dart';
import 'package:worksheet/src/core/formula/formula_reference_config.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/widgets/formula_bar.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  late SparseWorksheetData data;
  late WorksheetController controller;
  late EditController editController;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    data.setCell(const CellCoordinate(0, 0), CellValue.text('A1'));
    data.setCell(const CellCoordinate(1, 0), CellValue.text('A2'));
    data.setCell(const CellCoordinate(0, 1), CellValue.text('B1'));
    data.setCell(const CellCoordinate(2, 2), CellValue.number(42));
    controller = WorksheetController();
    editController = EditController();
  });

  tearDown(() {
    controller.dispose();
    editController.dispose();
    data.dispose();
  });

  Widget buildWorksheet({
    bool readOnly = false,
    EditController? ec,
    OnEditCellCallback? onEditCell,
    Map<int, double>? customRowHeights,
    double defaultColumnWidth = 100.0,
    WorksheetData? dataOverride,
    WorksheetData? rawData,
    FormulaReferenceConfig? formulaReferenceConfig =
        const FormulaReferenceConfig(),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: WorksheetThemeData(defaultColumnWidth: defaultColumnWidth),
          child: SizedBox(
            width: 800,
            height: 600,
            child: Worksheet(
              data: dataOverride ?? data,
              rawData: rawData,
              formulaReferenceConfig: formulaReferenceConfig,
              controller: controller,
              editController: ec,
              rowCount: 100,
              columnCount: 26,
              readOnly: readOnly,
              onEditCell: onEditCell,
              customRowHeights: customRowHeights,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildWorksheetWithFormulaBar({required FocusNode formulaBarFocus}) {
    void startEditSelectedCell() {
      final cell = controller.focusCell;
      if (cell == null) return;
      editController.startEdit(
        cell: cell,
        currentValue: data.getCell(cell),
        trigger: EditTrigger.programmatic,
      );
    }

    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 48,
              child: FormulaBar(
                editController: editController,
                idleText:
                    data
                        .getCell(
                          controller.focusCell ?? const CellCoordinate(0, 0),
                        )
                        ?.displayValue ??
                    '',
                focusNode: formulaBarFocus,
                onStartEdit: startEditSelectedCell,
              ),
            ),
            Expanded(
              child: WorksheetTheme(
                data: const WorksheetThemeData(),
                child: Worksheet(
                  data: data,
                  controller: controller,
                  editController: editController,
                  rowCount: 100,
                  columnCount: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void selectCell(int row, int col) {
    controller.selectCell(CellCoordinate(row, col));
  }

  group('FormulaBar focus', () {
    testWidgets(
      'clicking idle formula bar starts editing and keeps bar focus',
      (tester) async {
        final formulaBarFocus = FocusNode(debugLabel: 'formula bar');
        addTearDown(formulaBarFocus.dispose);

        selectCell(0, 0);
        await tester.pumpWidget(
          buildWorksheetWithFormulaBar(formulaBarFocus: formulaBarFocus),
        );
        await tester.pump();

        await tester.tap(find.byType(FormulaBar));
        await tester.pump();
        await tester.pump();

        expect(editController.isEditing, isTrue);
        expect(editController.editingCell, const CellCoordinate(0, 0));
        expect(editController.preferFormulaBarFocus, isTrue);
        expect(formulaBarFocus.hasFocus, isTrue);
      },
    );

    testWidgets('clicking formula bar during edit marks bar as focus owner', (
      tester,
    ) async {
      final formulaBarFocus = FocusNode(debugLabel: 'formula bar');
      addTearDown(formulaBarFocus.dispose);

      selectCell(0, 0);
      await tester.pumpWidget(
        buildWorksheetWithFormulaBar(formulaBarFocus: formulaBarFocus),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();
      expect(editController.isEditing, isTrue);
      expect(formulaBarFocus.hasFocus, isFalse);

      await tester.tap(find.byType(FormulaBar));
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.preferFormulaBarFocus, isTrue);
      expect(formulaBarFocus.hasFocus, isTrue);
    });

    testWidgets('Enter in formula bar commits and keeps typed text visible', (
      tester,
    ) async {
      final formulaBarFocus = FocusNode(debugLabel: 'formula bar');
      addTearDown(formulaBarFocus.dispose);

      selectCell(0, 0);
      await tester.pumpWidget(
        buildWorksheetWithFormulaBar(formulaBarFocus: formulaBarFocus),
      );
      await tester.pump();

      await tester.tap(find.byType(FormulaBar));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Committed');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Committed',
      );
      expect(
        data.getCell(const CellCoordinate(0, 0)),
        const CellValue.text('Committed'),
      );
    });

    testWidgets('Escape in formula bar restores idle cell text', (
      tester,
    ) async {
      final formulaBarFocus = FocusNode(debugLabel: 'formula bar');
      addTearDown(formulaBarFocus.dispose);

      selectCell(0, 0);
      await tester.pumpWidget(
        buildWorksheetWithFormulaBar(formulaBarFocus: formulaBarFocus),
      );
      await tester.pump();

      await tester.tap(find.byType(FormulaBar));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Discarded');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'A1',
      );
      expect(
        data.getCell(const CellCoordinate(0, 0)),
        const CellValue.text('A1'),
      );
    });

    testWidgets(
      'formula bar clears when edit ends and idle text is unchanged',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FormulaBar(editController: editController, idleText: ''),
            ),
          ),
        );

        editController.startEdit(
          cell: const CellCoordinate(10, 10),
          currentValue: null,
        );
        await tester.pump();

        editController.updateText('Typed');
        editController.syncEditorValueToFormulaBar(
          const TextEditingValue(
            text: 'Typed',
            selection: TextSelection.collapsed(offset: 5),
          ),
        );
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Typed',
        );

        editController.commitEdit(
          onCommit: (cell, value, {CellFormat? detectedFormat}) {},
        );
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
      },
    );
  });

  group('Type-to-edit (navigation mode)', () {
    testWidgets('pressing a printable character starts editing', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.editingCell, const CellCoordinate(0, 0));
      expect(editController.trigger, EditTrigger.typing);
    });

    testWidgets('digit starts editing with digit as initial text', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(1, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.editingCell, const CellCoordinate(1, 0));
      expect(editController.trigger, EditTrigger.typing);
      // The initial text should be the typed character
      expect(editController.currentText, '5');
    });

    testWidgets('Ctrl+A does NOT start editing (triggers select all)', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('Meta+C does NOT start editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('F2 starts editing with F2 trigger', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.trigger, EditTrigger.f2Key);
      // F2 should load the existing cell value (42 displays as '42' for integers)
      expect(editController.currentText, '42');
    });

    testWidgets('no editController: printable chars do nothing', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet()); // no editController
      selectCell(0, 0);
      await tester.pump();

      // This should NOT crash or start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      // No editController means no editing state to check
      // Just verify no crash occurred
    });

    testWidgets('readOnly: printable chars do nothing', (tester) async {
      await tester.pumpWidget(
        buildWorksheet(ec: editController, readOnly: true),
      );
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('no focused cell: printable chars do nothing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      // Don't select any cell
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(editController.isEditing, isFalse);
    });

    testWidgets('does not start editing if already editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing first
      editController.startEdit(
        cell: const CellCoordinate(0, 0),
        currentValue: CellValue.text('A1'),
        trigger: EditTrigger.f2Key,
      );
      await tester.pump();

      // Typing 'b' should go to the TextField, not start a new edit
      // The editController should still be editing cell (0,0)
      expect(editController.isEditing, isTrue);
      expect(editController.editingCell, const CellCoordinate(0, 0));
    });
  });

  group('Commit-and-navigate (edit mode)', () {
    testWidgets('Enter commits and moves selection down', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      // Start editing via type-to-edit
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.pump();
      await tester.pump(); // Let overlay render

      expect(editController.isEditing, isTrue);

      // Press Enter to commit and navigate down
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      // Selection should have moved down
      expect(controller.focusCell, const CellCoordinate(3, 2));
      // Data should be committed
      expect(data.getCell(const CellCoordinate(2, 2))?.displayValue, '9');
    });

    testWidgets('Shift+Enter commits and moves selection up', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(3, 2);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Shift+Enter to commit and navigate up
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('Tab commits and moves selection right', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Tab to commit and navigate right
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 3));
    });

    testWidgets('Shift+Tab commits and moves selection left', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 3);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Shift+Tab to commit and navigate left
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('ArrowDown commits and moves selection down', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(3, 2));
      expect(data.getCell(const CellCoordinate(2, 2))?.displayValue, '4');
    });

    testWidgets('ArrowUp commits and moves selection up', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(3, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('ArrowRight moves text cursor, stays in edit mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(controller.focusCell, const CellCoordinate(2, 2));
    });

    testWidgets('ArrowLeft moves text cursor, stays in edit mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(controller.focusCell, const CellCoordinate(2, 3));
    });

    testWidgets('Escape cancels edit, does not navigate', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(2, 2);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // Press Escape to cancel
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      // Selection should NOT move
      expect(controller.focusCell, const CellCoordinate(2, 2));
      // Original value should be unchanged
      expect(data.getCell(const CellCoordinate(2, 2)), CellValue.number(42));
    });
  });

  group('Backspace/Delete behavior', () {
    testWidgets('Backspace clears cell when not editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Cell has value 'A1'
      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, 'A1');

      // Press Backspace — should clear the cell
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
      expect(editController.isEditing, isFalse);
    });

    testWidgets('Delete clears cell when not editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 1);
      await tester.pump();

      expect(data.getCell(const CellCoordinate(0, 1))?.displayValue, 'B1');

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(data.getCell(const CellCoordinate(0, 1)), isNull);
      expect(editController.isEditing, isFalse);
    });

    testWidgets('Backspace does not clear cell when editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing via type-to-edit
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);

      // The original cell value should still be in the data
      // (editing hasn't committed yet, type-to-edit replaces)
      final valueBefore = data.getCell(const CellCoordinate(0, 0));

      // Press Backspace — should NOT clear the cell, should edit text
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Should still be editing
      expect(editController.isEditing, isTrue);
      // Cell data should not have been cleared by ClearCellsAction
      expect(data.getCell(const CellCoordinate(0, 0)), valueBefore);
    });

    testWidgets('Delete does not clear cell when editing', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing via F2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);
      final valueBefore = data.getCell(const CellCoordinate(0, 0));

      // Press Delete — should NOT clear the cell
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(data.getCell(const CellCoordinate(0, 0)), valueBefore);
    });
  });

  group('Integration', () {
    testWidgets('type character starts editing, Enter commits and moves down', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Type 'H' to start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.trigger, EditTrigger.typing);

      // Press Enter to commit
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(controller.focusCell, const CellCoordinate(1, 0));
    });

    testWidgets('software keyboard done commits formula and closes editor', (
      tester,
    ) async {
      final evaluatedData = _EvaluatingWrapper(data);
      await tester.pumpWidget(
        buildWorksheet(
          ec: editController,
          dataOverride: evaluatedData,
          rawData: data,
        ),
      );
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '=B5');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isFalse);
      expect(
        data.getCell(const CellCoordinate(0, 0)),
        const CellValue.formula('=B5'),
      );
      expect(
        evaluatedData.getCell(const CellCoordinate(0, 0)),
        CellValue.number(15),
      );
      expect(controller.focusCell, const CellCoordinate(1, 0));
    });

    testWidgets('F2 starts editing with full cell value', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.trigger, EditTrigger.f2Key);
      expect(editController.currentText, 'A1');
    });

    testWidgets('focus returns to worksheet after commit', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      await tester.pump();

      // Commit with Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      // After commit, the worksheet should be able to handle keyboard again.
      // Send an arrow key to verify focus returned.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // If focus returned properly, the selection should have moved
      expect(controller.focusCell, const CellCoordinate(1, 1));
    });

    testWidgets('focus returns to worksheet after cancel', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(0, 0);
      await tester.pump();

      // Start editing
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      await tester.pump();

      // Cancel with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();

      // After cancel, the worksheet should handle keyboard.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // If focus returned, selection should have moved
      expect(controller.focusCell, const CellCoordinate(1, 0));
    });

    testWidgets('existing navigation shortcuts work when not editing', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(5, 5);
      await tester.pump();

      // Arrow keys should still work for navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(6, 5));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.focusCell, const CellCoordinate(6, 6));
    });

    testWidgets('onEditCell callback fires alongside editController on F2', (
      tester,
    ) async {
      CellCoordinate? editedCell;

      await tester.pumpWidget(
        buildWorksheet(
          ec: editController,
          onEditCell: (cell) => editedCell = cell,
        ),
      );
      selectCell(3, 3);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      // Both the callback and the editController should be triggered
      expect(editedCell, const CellCoordinate(3, 3));
      expect(editController.isEditing, isTrue);
    });
  });

  group('Wrap-text expansion timing', () {
    testWidgets(
      'wrap-text cell expansion updates selection renderer in same frame',
      (tester) async {
        // Set up a wrap-text, right-aligned, bottom-aligned cell
        const cell = CellCoordinate(5, 1);
        data.setCell(cell, CellValue.text('Hi'));
        data.setStyle(
          cell,
          const CellStyle(
            wrapText: true,
            textAlignment: CellTextAlignment.right,
            verticalAlignment: CellVerticalAlignment.bottom,
          ),
        );

        await tester.pumpWidget(buildWorksheet(ec: editController));
        selectCell(5, 1);
        await tester.pump();

        // Start editing via F2
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();
        await tester.pump();
        expect(editController.isEditing, isTrue);

        // Type multi-line text that overflows the 24px row height.
        // Alt+Enter inserts a newline in wrap-text mode.
        // Three lines of text at 14px font (~16.8px per line) = ~50.4px,
        // which exceeds the 24px cell height and should expand downward.
        editController.updateText('Line1\nLine2\nLine3');
        await tester.pump();

        // Now tap in the area below the original cell (row 6 area).
        // Default layout: headers are 50px wide, 24px tall.
        // Cell (5,1): x = 50 + 100 = 150, y = 24 + 5*24 = 144, 100px wide, 24px tall.
        // Row 6 starts at y = 144 + 24 = 168.
        // If expansion worked, tapping at y=175 (row 6 area, inside expanded bounds)
        // should NOT commit the edit.
        await tester.tapAt(const Offset(180, 175));
        await tester.pump();

        // The edit should still be active because the tap was inside the
        // expanded editing area.
        expect(
          editController.isEditing,
          isTrue,
          reason: 'Tap inside expanded area should not commit edit',
        );
      },
    );

    testWidgets(
      'bottom-aligned wrap cell with tall row expands on first newline',
      (tester) async {
        // Matches example/wrap_text.dart cell (5,1): 60px row, 200px column,
        // bottom+right aligned, text "Bottom-right-aligned\nwrapped text".
        // After one Alt+Enter → "...\nwrapped text\n", the cursor is on a
        // blank line 3. The vertical offset is ~22px, so needed height =
        // 22 + ~50px + 4 = ~76px > 60px → should expand into row 6.
        const cell = CellCoordinate(5, 1);
        data.setCell(
          cell,
          CellValue.text('Bottom-right-aligned\nwrapped text'),
        );
        data.setStyle(
          cell,
          const CellStyle(
            wrapText: true,
            textAlignment: CellTextAlignment.right,
            verticalAlignment: CellVerticalAlignment.bottom,
          ),
        );

        await tester.pumpWidget(
          buildWorksheet(
            ec: editController,
            customRowHeights: {5: 60},
            defaultColumnWidth: 200,
          ),
        );
        selectCell(5, 1);
        await tester.pump();

        // Start editing via F2
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();
        await tester.pump();
        expect(editController.isEditing, isTrue);

        // Simulate one Alt+Enter (adds trailing newline)
        editController.updateText('Bottom-right-aligned\nwrapped text\n');
        await tester.pump();

        // Tap in the row below (row 6). With 60px row at row 5:
        // Row 5: y = 24 + 5*24 = 144 (rows 0-4 are 24px each)
        // Wait — customRowHeights only sets row 5 to 60. Rows 0-4 are 24px.
        // Row 5 top: 24(header) + 5*24 = 144, bottom: 144 + 60 = 204
        // Row 6 starts at y=204.
        // Tap at y=210 (inside row 6, which should be inside expanded area).
        // x = 50(header) + 200(col0) + 50 = 300 (middle of col 1)
        await tester.tapAt(const Offset(300, 210));
        await tester.pump();

        expect(
          editController.isEditing,
          isTrue,
          reason:
              'First newline in bottom-aligned cell should expand; tap in '
              'expanded area should not commit',
        );
      },
    );

    testWidgets(
      'wrap-text cell near viewport bottom auto-scrolls on expansion',
      (tester) async {
        // Place a wrap-text cell near the viewport bottom.
        // Widget height = 600, header = 24, default row = 24.
        // Row 23 top = 24 + 23*24 = 576, bottom = 600 — last visible row.
        const cell = CellCoordinate(23, 0);
        data.setCell(cell, CellValue.text('Hi'));
        data.setStyle(cell, const CellStyle(wrapText: true));

        await tester.pumpWidget(buildWorksheet(ec: editController));
        selectCell(23, 0);
        await tester.pump();

        // Record scroll offset before editing
        final vController = controller.verticalScrollController;
        final offsetBefore = vController.offset;

        // Start editing via F2
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();
        await tester.pump();
        expect(editController.isEditing, isTrue);

        // Simulate adding multiple lines that overflow the viewport bottom.
        // Three lines at ~16.8px each ≈ 50px, exceeding the 24px cell.
        // Expanded bottom ≈ 576 + 50 = 626, which exceeds viewport (600).
        editController.updateText('Line1\nLine2\nLine3');
        await tester.pump();

        // The viewport should have scrolled down to keep the editor visible.
        expect(
          vController.offset,
          greaterThan(offsetBefore),
          reason:
              'Viewport should auto-scroll when wrap-text editor '
              'overflows below the viewport bottom',
        );
      },
    );

    testWidgets('tap outside expanded wrap-text area commits edit', (
      tester,
    ) async {
      const cell = CellCoordinate(5, 1);
      data.setCell(cell, CellValue.text('Hi'));
      data.setStyle(
        cell,
        const CellStyle(
          wrapText: true,
          textAlignment: CellTextAlignment.right,
          verticalAlignment: CellVerticalAlignment.bottom,
        ),
      );

      await tester.pumpWidget(buildWorksheet(ec: editController));
      selectCell(5, 1);
      await tester.pump();

      // Start editing via F2
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.pump();
      expect(editController.isEditing, isTrue);

      // Type short text that fits in the cell (no expansion)
      editController.updateText('Short');
      await tester.pump();

      // Tap well outside the cell area (e.g. in a completely different cell)
      // Cell (0,0) area: x = 50 + 0 = 50, y = 24 + 0 = 24
      await tester.tapAt(const Offset(60, 30));
      await tester.pump();

      // The edit should be committed
      expect(
        editController.isEditing,
        isFalse,
        reason: 'Tap outside editing area should commit edit',
      );
    });
  });

  group('Formula reference editing', () {
    testWidgets(
      'iOS formula reference touch does not turn next drag into pinch zoom',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        await tester.pumpWidget(
          buildWorksheet(
            ec: editController,
            formulaReferenceConfig: const FormulaReferenceConfig(),
          ),
        );
        selectCell(0, 0);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pump();
        await tester.pump();
        expect(editController.isEditing, isTrue);

        final referenceTouch = TestPointer(1, PointerDeviceKind.touch);
        await tester.sendEventToBinding(
          referenceTouch.down(const Offset(175, 60)),
        );
        await tester.sendEventToBinding(referenceTouch.up());
        await tester.pump();

        editController.requestExternalCommit(
          onFallbackCommit: (cell, value, {detectedFormat}) {
            data.setCell(cell, value);
          },
        );
        await tester.pump();

        final zoomBeforeDrag = controller.zoom;
        final dragTouch = TestPointer(2, PointerDeviceKind.touch);
        await tester.sendEventToBinding(dragTouch.down(const Offset(200, 200)));
        await tester.sendEventToBinding(dragTouch.move(const Offset(260, 260)));
        await tester.sendEventToBinding(dragTouch.up());
        await tester.pump();

        debugDefaultTargetPlatformOverride = null;
        expect(controller.zoom, zoomBeforeDrag);
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'clicking a cell in formula mode inserts ref and Enter commits',
      (tester) async {
        await tester.pumpWidget(buildWorksheet(ec: editController));
        selectCell(0, 0);
        await tester.pump();

        // Start editing by typing '='  — enters formula mode.
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(editController.isEditing, isTrue);
        expect(editController.currentText, '=');
        expect(
          editController.isFormulaMode(const FormulaReferenceConfig()),
          isTrue,
          reason: 'Should be in formula mode with text starting with =',
        );

        // Tap cell B2 (column 1, row 1) using pointer directly to ensure
        // the Listener onPointerDown receives the event.
        // Screen coords: x = 50 (header) + 100 (col 0) + 50 = 200,
        //                y = 24 (header) + 24 (row 0) + 12 = 60
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.down(const Offset(200, 60)));
        await tester.pump();
        await tester.sendEventToBinding(pointer.up());
        await tester.pump();

        // Should still be editing with the ref inserted.
        expect(
          editController.isEditing,
          isTrue,
          reason:
              'Formula mode tap should NOT commit. '
              'text=${editController.currentText}',
        );
        expect(editController.currentText, contains('B2'));

        // Now press Enter to commit.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(
          editController.isEditing,
          isFalse,
          reason: 'Enter should commit the formula',
        );
        // Data should contain the formula.
        expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, '=B2');
      },
    );

    testWidgets(
      'arrow keys insert cell references at operator boundary in formula mode',
      (tester) async {
        await tester.pumpWidget(buildWorksheet(ec: editController));
        selectCell(2, 2); // C3
        await tester.pump();

        // Start editing by typing '='
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pump();
        await tester.pump();

        expect(editController.isEditing, isTrue);
        expect(editController.currentText, '=');

        // Press arrow-down: cursor is right after '=' (operator boundary)
        // so it should insert a cell reference instead of committing.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(
          editController.isEditing,
          isTrue,
          reason: 'Arrow at operator boundary should not commit',
        );
        // Should have inserted a ref for the cell below the anchor (C3 → C4)
        expect(editController.currentText, contains('C4'));
      },
    );

    testWidgets(
      'arrow keys at end of existing ref insert new ref in formula mode',
      (tester) async {
        await tester.pumpWidget(buildWorksheet(ec: editController));
        selectCell(2, 2); // C3
        await tester.pump();

        // Start editing a formula with an existing ref.
        // Type '=A1+' to set up a formula with cursor after operator.
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pump();
        await tester.pump();

        // Simulate typing 'A1+' by updating the text controller directly.
        final rtc = editController.richTextController!;
        rtc.value = const TextEditingValue(
          text: '=A1+',
          selection: TextSelection.collapsed(offset: 4),
        );
        editController.updateText('=A1+');
        await tester.pump();

        // Press arrow-right: cursor is after '+' (operator boundary)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expect(
          editController.isEditing,
          isTrue,
          reason: 'Arrow at operator boundary should not commit',
        );
        // The ref inserted should be based on the selection anchor's neighbor
        final text = editController.currentText;
        expect(text, startsWith('=A1+'));
        expect(
          text.length,
          greaterThan(4),
          reason: 'A cell ref should have been inserted after +',
        );
      },
    );

    testWidgets(
      'arrow keys within an existing ref move cursor (not reference)',
      (tester) async {
        await tester.pumpWidget(buildWorksheet(ec: editController));
        selectCell(2, 2); // C3
        await tester.pump();

        // Start editing by typing '='
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pump();
        await tester.pump();

        // Set formula to '=A1' with cursor inside the ref (between A and 1).
        final rtc = editController.richTextController!;
        rtc.value = const TextEditingValue(
          text: '=A1',
          selection: TextSelection.collapsed(offset: 2), // between A and 1
        );
        editController.updateText('=A1');
        await tester.pump();

        // Press arrow-down: cursor is within ref 'A1', NOT at an operator
        // boundary, so the arrow key should move the cursor (or be consumed
        // without committing in formula mode) — it should NOT insert/move a
        // cell reference.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(
          editController.isEditing,
          isTrue,
          reason: 'Arrow within ref should not commit in formula mode',
        );
        // Text should be unchanged — no reference insertion or movement.
        expect(editController.currentText, '=A1');
      },
    );
  });

  group('rawData parameter', () {
    testWidgets('F2 shows raw formula when rawData is provided', (
      tester,
    ) async {
      // Raw data has the original formula.
      final rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
      rawData.setCell(
        const CellCoordinate(0, 0),
        CellValue.formula('=SUM(A1:A5)'),
      );

      // Wrapper evaluates formulas → returns the computed number.
      final wrapper = _EvaluatingWrapper(rawData);

      await tester.pumpWidget(
        buildWorksheet(
          ec: editController,
          dataOverride: wrapper,
          rawData: rawData,
        ),
      );

      selectCell(0, 0);
      await tester.pump();

      // F2 to start editing.
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.currentText, equals('=SUM(A1:A5)'));

      rawData.dispose();
    });

    testWidgets('F2 shows evaluated value when rawData is not provided', (
      tester,
    ) async {
      // Raw data has the original formula.
      final rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
      rawData.setCell(
        const CellCoordinate(0, 0),
        CellValue.formula('=SUM(A1:A5)'),
      );

      // Wrapper evaluates formulas → returns the computed number.
      final wrapper = _EvaluatingWrapper(rawData);

      // No rawData parameter — editor should see the wrapper's value.
      await tester.pumpWidget(
        buildWorksheet(ec: editController, dataOverride: wrapper),
      );

      selectCell(0, 0);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.currentText, equals('15'));

      rawData.dispose();
    });
  });

  group('formula arrow keys should move cursor, not insert references', () {
    testWidgets(
      'ArrowLeft through operator boundary does not insert reference',
      (tester) async {
        // Reproduce: edit =D2+D3+D4, arrow-left from end, cursor should
        // pass through the "+" without triggering reference insertion.
        final rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
        rawData.setCell(
          const CellCoordinate(5, 3), // D6 in the example
          const CellValue.formula('=D2+D3+D4'),
        );
        final wrapper = _EvaluatingWrapper(rawData);

        await tester.pumpWidget(
          buildWorksheet(
            ec: editController,
            dataOverride: wrapper,
            rawData: rawData,
          ),
        );

        selectCell(5, 3);
        await tester.pump();

        // F2 to start editing — cursor goes to end of formula.
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();

        expect(editController.isEditing, isTrue);
        expect(editController.currentText, '=D2+D3+D4');

        // Place cursor at end explicitly (F2 on formula selects all by
        // default; force cursor to end).
        final rtc = editController.richTextController!;
        rtc.selection = const TextSelection.collapsed(offset: 9); // end
        await tester.pump();

        // ArrowLeft 1: offset 9→8 (within D4)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(
          editController.currentText,
          '=D2+D3+D4',
          reason: 'ArrowLeft #1 should move cursor, not modify text',
        );

        // ArrowLeft 2: offset 8→7 (now right after "+")
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(
          editController.currentText,
          '=D2+D3+D4',
          reason: 'ArrowLeft #2 should move cursor, not modify text',
        );

        // ArrowLeft 3: offset 7→6 — charBefore is "+", which is an operator
        // boundary. This MUST still move the cursor, not insert a reference.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(
          editController.currentText,
          '=D2+D3+D4',
          reason:
              'ArrowLeft across "+" operator boundary should move cursor, '
              'not insert a cell reference',
        );
        expect(editController.isEditing, isTrue);
      },
    );
  });

  group('formula cell arrow keys (no FormulaReferenceConfig)', () {
    testWidgets('ArrowDown does not commit formula cell edit', (tester) async {
      // Set up a formula cell — same as formula_richtext.dart example.
      final rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
      rawData.setCell(
        const CellCoordinate(2, 2),
        const CellValue.formula('=A1+B1'),
      );
      final wrapper = _EvaluatingWrapper(rawData);

      await tester.pumpWidget(
        buildWorksheet(
          ec: editController,
          dataOverride: wrapper,
          rawData: rawData,
        ),
      );

      // Select the formula cell and start editing with F2.
      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.currentText, '=A1+B1');
      expect(editController.isEditingFormula, isTrue);

      // Press ArrowDown — should NOT commit.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        editController.isEditing,
        isTrue,
        reason: 'ArrowDown should not commit a formula cell edit',
      );
      expect(editController.currentText, '=A1+B1');

      rawData.dispose();
    });

    testWidgets('ArrowUp does not commit formula cell edit', (tester) async {
      final rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
      rawData.setCell(
        const CellCoordinate(2, 2),
        const CellValue.formula('=A1+B1'),
      );
      final wrapper = _EvaluatingWrapper(rawData);

      await tester.pumpWidget(
        buildWorksheet(
          ec: editController,
          dataOverride: wrapper,
          rawData: rawData,
        ),
      );

      selectCell(2, 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        editController.isEditing,
        isTrue,
        reason: 'ArrowUp should not commit a formula cell edit',
      );

      rawData.dispose();
    });

    testWidgets('ArrowDown on non-formula cell still commits', (tester) async {
      await tester.pumpWidget(buildWorksheet(ec: editController));

      selectCell(2, 2); // cell with value 42
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();

      expect(editController.isEditing, isTrue);
      expect(editController.currentText, '42');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        editController.isEditing,
        isFalse,
        reason: 'ArrowDown should commit a non-formula cell edit',
      );
    });
  });
}

/// Test wrapper that replaces formula cells with evaluated numbers.
class _EvaluatingWrapper extends DelegatingWorksheetData {
  _EvaluatingWrapper(super.inner);

  @override
  CellValue? getCell(CellCoordinate coord) {
    final value = super.getCell(coord);
    if (value != null && value.type == CellValueType.formula) {
      return CellValue.number(15);
    }
    return value;
  }
}
