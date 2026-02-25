import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'dart:async';
import 'dart:developer' as developer; // For developer.log

// Reusing MockWorksheetData from memory_benchmark.dart
// A simple mock for WorksheetData to control data size for testing
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

  // --- Methods from WorksheetData with default implementations in the abstract class ---
  // Removed @override from these as they are not abstract and do not need to be overridden.
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

  // Additional methods found in WorksheetData which are not abstract
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
  group('Startup Benchmarks - Time To First Render (TTFR)', () {
    // Moved completer declaration to be local to the function
    Future<void> measureTTFR(
      WidgetTester tester,
      String description, {
      int rows = 10,
      int cols = 5,
    }) async {
      final Stopwatch stopwatch = Stopwatch()..start();
      Completer<void> completer = Completer<void>(); // Initialized here

      WidgetsBinding.instance.addPostFrameCallback((_) {
        stopwatch.stop();
        developer.log('$description TTFR: ${stopwatch.elapsedMicroseconds / 1000} ms', name: 'TTFR_Benchmark');
        completer.complete();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Worksheet(
              data: MockWorksheetData(rows: rows, cols: cols),
            ),
          ),
        ),
      );

      await completer.future; // Wait for the post-frame callback
    }

    testWidgets('TTFR for a small worksheet (10x5)', (WidgetTester tester) async {
      await measureTTFR(tester, 'Small Worksheet', rows: 10, cols: 5);
      expect(find.byType(Worksheet), findsOneWidget); // Basic verification
    });

    testWidgets('TTFR for a medium worksheet (100x20)', (WidgetTester tester) async {
      await measureTTFR(tester, 'Medium Worksheet', rows: 100, cols: 20);
      expect(find.byType(Worksheet), findsOneWidget);
    });

    testWidgets('TTFR for a large worksheet (1000x50)', (WidgetTester tester) async {
      await measureTTFR(tester, 'Large Worksheet', rows: 1000, cols: 50);
      expect(find.byType(Worksheet), findsOneWidget);
    });
  });
}
