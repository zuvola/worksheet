import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'dart:async';
import 'dart:developer' as developer; // For developer.log

// Reusing MockWorksheetData from other benchmarks
class MockWorksheetData implements WorksheetData {
  final int rows;
  final int cols;
  final StreamController<DataChangeEvent> _changesController;
  @override
  final MergedCellRegistry mergedCells = MergedCellRegistry();

  MockWorksheetData({this.rows = 1000, this.cols = 100})
      : _changesController = StreamController.broadcast();

  @override
  CellValue? getCell(CellCoordinate coord) {
    if (coord.row < rows && coord.column < cols) {
      return CellValue.text('R${coord.row}C${coord.column}');
    }
    return null;
  }

  @override
  CellStyle? getStyle(CellCoordinate coord) => null;

  @override
  void setCell(CellCoordinate coord, CellValue? value) {}

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {}

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) {
    final dummyBatch = _MockWorksheetDataBatch();
    updates(dummyBatch);
    notifyListeners();
  }

  @override
  Future<void> batchUpdateAsync(
      Future<void> Function(WorksheetDataBatch batch) updates) async {
    final dummyBatch = _MockWorksheetDataBatch();
    await updates(dummyBatch);
    notifyListeners();
  }

  @override
  Stream<DataChangeEvent> get changes => _changesController.stream;

  @override
  int get rowCount => rows;

  @override
  int get columnCount => cols;

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(CellRange range) => const [];

  @override
  void clearRange(CellRange range) {}

  @override
  CellRange? smartFill(CellRange range, CellCoordinate destination, [Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator]) => null;

  @override
  void fillRange(CellCoordinate source, CellRange range, [Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator]) {}

  @override
  void mergeCells(CellRange range) {}

  @override
  void unmergeCells(CellCoordinate cell) {}

  @override
  void dispose() {
    _changesController.close();
  }

  CellFormat? getFormat(CellCoordinate coord) => null;
  void setFormat(CellCoordinate coord, CellFormat? format) {}
  List<TextSpan>? getRichText(CellCoordinate coord) => null;
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}
  bool hasValue(CellCoordinate coord) => getCell(coord) != null;
  void clearRichTextInRange(CellRange range) {}
  Iterable<MapEntry<CellCoordinate, List<TextSpan>>> getRichTextInRange(CellRange range) => const [];
  Iterable<MapEntry<CellCoordinate, CellStyle>> getStylesInRange(CellRange range) => const [];
  Iterable<MapEntry<CellCoordinate, CellFormat>> getFormatsInRange(CellRange range) => const [];
  void unmergeCellsInRange(CellRange range) {}
  void moveMerges(CellRange source, CellCoordinate destination) {}
  void replicateMerges({required CellRange sourceRange, required CellRange targetRange, required bool vertical}) {}
  int? findNextPopulatedRow(int column, int fromRow) => null;
  int? findPrevPopulatedRow(int column, int fromRow) => null;
  int? findNextPopulatedColumn(int row, int fromColumn) => null;
  int? findPrevPopulatedColumn(int row, int fromColumn) => null;
  bool get hasFormulas => false;
  bool get hasRichText => false;
  bool get hasMergedCells => false;
  bool get hasStyles => false;
  List<CellCoordinate> get allCellsWithData => [];
  Map<CellCoordinate, CellStyle> get allStyles => {};
  List<CellRange> get allMergedCells => [];
  CellValue? getFormula(CellCoordinate coord) => null;
  Cell? getRawCell(CellCoordinate coord) => null;
  bool hasFormula(CellCoordinate coord) => false;
  bool hasRichTextAt(CellCoordinate coord) => false;
  bool hasStyle(CellCoordinate coord) => false;
  bool hasFormat(CellCoordinate coord) => false;
  void clearFormat(CellCoordinate coord) {}
  void clearStyle(CellCoordinate coord) {}

  void notifyListeners() {
    _changesController.add(DataChangeEvent.reset());
  }
}

// Dummy implementation for WorksheetDataBatch for the mock
class _MockWorksheetDataBatch implements WorksheetDataBatch {
  @override
  void clearRange(CellRange range) {}

  @override
  void clearFormats(CellRange range) {}

  @override
  void clearStyles(CellRange range) {}

  @override
  void clearValues(CellRange range) {}

  @override
  void copyRange(CellRange source, CellCoordinate destination) {}

  @override
  void fillRangeWithCell(CellRange range, Cell? value) {}

  @override
  void setCell(CellCoordinate coord, CellValue? value) {}

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {}

  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {}
}


void main() {
  group('Interaction Benchmarks', () {
    Future<void> measureInteraction(
      WidgetTester tester,
      String description,
      Future<void> Function(WorksheetController controller, EditController editController) action, {
      int rows = 100,
      int cols = 20,
    }) async {
      final WorksheetController controller = WorksheetController();
      final EditController editController = EditController(); // Instantiate EditController
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Worksheet(
              data: MockWorksheetData(rows: rows, cols: cols),
              controller: controller,
              editController: editController, // Pass EditController
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Stopwatch stopwatch = Stopwatch()..start();
      await action(controller, editController); // Pass editController to action
      stopwatch.stop();

      developer.log(
          '$description latency: ${stopwatch.elapsedMicroseconds / 1000} ms',
          name: 'Interaction_Benchmark');
    }

    testWidgets('Typing in a cell latency', (WidgetTester tester) async {
      await measureInteraction(
        tester,
        'Typing in a cell',
        (controller, editController) async { // Receive editController
          final cell = CellCoordinate(0, 0);
          controller.selectionController.selectCell(cell);
          await tester.pumpAndSettle();

          // Use EditController to start edit
          editController.startEdit(cell: cell, initialText: '', trigger: EditTrigger.programmatic); // Corrected EditTrigger
          await tester.pumpAndSettle();

          // Simulate typing a character
          await tester.enterText(find.byType(EditableText), 'A'); // Now EditableText should be found
          await tester.pumpAndSettle();
        },
        rows: 10,
        cols: 5,
      );
      // Basic verification that a widget exists
      expect(find.byType(Worksheet), findsOneWidget);
    });

    testWidgets('Resizing a column latency', (WidgetTester tester) async {
      await measureInteraction(
        tester,
        'Resizing a column',
        (controller, editController) async { // Receive editController, though not used here
          // Find the worksheet widget
          final Finder worksheetFinder = find.byType(Worksheet);
          expect(worksheetFinder, findsOneWidget);

          // Get the context of the worksheet to access layout solver and theme
          final BuildContext context = tester.element(worksheetFinder);
          final WorksheetThemeData theme = WorksheetTheme.of(context);
          final LayoutSolver layoutSolver = controller.layoutSolver!;

          // Assuming default header width and height
          final double headerHeight = theme.columnHeaderHeight;
          final double headerWidth = theme.rowHeaderWidth;

          // Target the resize handle for column 1 (just after the first column header)
          // Adjust coordinates to be relative to the widget's top-left corner
          final RenderBox renderBox = tester.renderObject(worksheetFinder);
          final Offset worksheetTopLeft = renderBox.localToGlobal(Offset.zero);

          final Offset resizeHandleStart = worksheetTopLeft + Offset(
            headerWidth + layoutSolver.getColumnWidth(0) * controller.zoom - 2, // 2 pixels to the left of the actual divider
            headerHeight / 2,
          );

          // Perform a drag gesture to resize the column
          final TestGesture gesture = await tester.startGesture(resizeHandleStart);
          await tester.pump(); // Start the gesture

          await gesture.moveBy(const Offset(20, 0)); // Drag 20 pixels to the right
          await tester.pumpAndSettle(); // Wait for layout and rendering to settle

          await gesture.up(); // End the gesture
          await tester.pumpAndSettle();
        },
        rows: 10,
        cols: 5,
      );
       expect(find.byType(Worksheet), findsOneWidget);
    });

    // TODO: Add benchmark for Copy-Paste of a large range
  });
}
