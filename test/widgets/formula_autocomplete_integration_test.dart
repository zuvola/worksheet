import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  const functions = [
    FormulaFunction(name: 'ABS', signature: 'ABS(number)'),
    FormulaFunction(name: 'AVERAGE', signature: 'AVERAGE(n1, [n2])'),
    FormulaFunction(name: 'SUM', signature: 'SUM(n1, [n2])'),
    FormulaFunction(name: 'SUMIF', signature: 'SUMIF(range, criteria)'),
    FormulaFunction(name: 'SUMPRODUCT', signature: 'SUMPRODUCT(a1, [a2])'),
  ];

  const autocompleteConfig = FormulaAutocompleteConfig(functions: functions);

  Widget buildTestWorksheet({
    FormulaAutocompleteConfig? config = autocompleteConfig,
    Map<(int, int), Cell>? cells,
  }) {
    final data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: cells ?? {},
    );
    final editController = EditController();
    final worksheetController = WorksheetController();
    return MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: data,
            controller: worksheetController,
            editController: editController,
            rowCount: 100,
            columnCount: 10,
            formulaAutocompleteConfig: config,
            formulaReferenceConfig: const FormulaReferenceConfig(),
          ),
        ),
      ),
    );
  }

  group('Formula autocomplete integration', () {
    testWidgets('no autocomplete dropdown when config is null', (tester) async {
      await tester.pumpWidget(buildTestWorksheet(config: null));
      await tester.pump();

      // Verify no AutocompleteDropdown exists
      expect(find.byType(AutocompleteDropdown), findsNothing);
    });

    testWidgets('autocomplete controller created when config provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWorksheet());
      await tester.pump();

      // The widget tree should build without errors
      expect(find.byType(Worksheet), findsOneWidget);
    });

    testWidgets('autocomplete dropdown not shown when not editing', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWorksheet());
      await tester.pump();

      expect(find.byType(AutocompleteDropdown), findsNothing);
    });

    testWidgets('AutocompleteController basic lifecycle', (tester) async {
      final controller = AutocompleteController(config: autocompleteConfig);
      addTearDown(controller.dispose);

      // Not visible initially
      expect(controller.isVisible, isFalse);

      // Typing =SU shows dropdown
      controller.onTextChanged('=SU', 3);
      expect(controller.isVisible, isTrue);
      expect(controller.matches.length, 3); // SUM, SUMIF, SUMPRODUCT

      // Navigate down
      controller.selectNext();
      expect(controller.selectedIndex, 1);

      // Accept
      final result = controller.accept();
      expect(result?.function.name, 'SUMIF');
      expect(controller.isVisible, isFalse);
    });

    testWidgets('AutocompleteController dismiss', (tester) async {
      final controller = AutocompleteController(config: autocompleteConfig);
      addTearDown(controller.dispose);

      controller.onTextChanged('=SU', 3);
      expect(controller.isVisible, isTrue);

      controller.dismiss();
      expect(controller.isVisible, isFalse);
    });

    testWidgets('AutocompleteController non-formula text', (tester) async {
      final controller = AutocompleteController(config: autocompleteConfig);
      addTearDown(controller.dispose);

      controller.onTextChanged('hello', 5);
      expect(controller.isVisible, isFalse);
    });

    testWidgets('AutocompleteController backspace re-filters', (tester) async {
      final controller = AutocompleteController(config: autocompleteConfig);
      addTearDown(controller.dispose);

      controller.onTextChanged('=SUM', 4);
      expect(controller.matches.length, 3); // SUM, SUMIF, SUMPRODUCT

      controller.onTextChanged('=SU', 3);
      expect(controller.matches.length, 3); // same matches

      controller.onTextChanged('=S', 2);
      expect(controller.matches.length, 3); // SUM, SUMIF, SUMPRODUCT
    });

    testWidgets('AutocompleteController no dropdown when typing digits', (
      tester,
    ) async {
      final controller = AutocompleteController(config: autocompleteConfig);
      addTearDown(controller.dispose);

      controller.onTextChanged('=A1', 3);
      expect(controller.isVisible, isFalse);
    });
  });
}
