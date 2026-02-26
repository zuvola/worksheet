import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'dart:async';

// A simple mock for WorksheetData to control data size for testing
class MockWorksheetData implements WorksheetData {
  final int rows;
  final int cols;
  final StreamController<DataChangeEvent> _changesController;
  @override
  final MergedCellRegistry mergedCells = MergedCellRegistry(); // Minimal mergedCells

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
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) async {
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
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) => const [];

  @override
  void clearRange(CellRange range) {}

  @override
  CellRange? smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) => null;

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {}

  @override
  void mergeCells(CellRange range) {}

  @override
  void unmergeCells(CellCoordinate cell) {}

  @override
  void dispose() {
    _changesController.close();
  }

  @override
  CellFormat? getFormat(CellCoordinate coord) => null;
  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {}
  @override
  List<TextSpan>? getRichText(CellCoordinate coord) => null;
  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}
  @override
  bool hasValue(CellCoordinate coord) => getCell(coord) != null;
  @override
  void clearRichTextInRange(CellRange range) {}
  @override
  Iterable<MapEntry<CellCoordinate, List<TextSpan>>> getRichTextInRange(
    CellRange range,
  ) => const [];
  @override
  Iterable<MapEntry<CellCoordinate, CellStyle>> getStylesInRange(
    CellRange range,
  ) => const [];
  @override
  Iterable<MapEntry<CellCoordinate, CellFormat>> getFormatsInRange(
    CellRange range,
  ) => const [];
  @override
  void unmergeCellsInRange(CellRange range) {}
  @override
  void moveMerges(CellRange source, CellCoordinate destination) {}
  @override
  void replicateMerges({
    required CellRange sourceRange,
    required CellRange targetRange,
    required bool vertical,
  }) {}
  @override
  int? findNextPopulatedRow(int column, int fromRow) => null;
  @override
  int? findPrevPopulatedRow(int column, int fromRow) => null;
  @override
  int? findNextPopulatedColumn(int row, int fromColumn) => null;
  @override
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
  group('Memory Benchmarks', () {
    testWidgets('Large worksheet renders without crash', (
      WidgetTester tester,
    ) async {
      const int largeRows = 5000;
      const int largeCols = 50;

      final MockWorksheetData data = MockWorksheetData(
        rows: largeRows,
        cols: largeCols,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Worksheet(data: data)),
        ),
      );
      await tester.pumpAndSettle(); // Settle all animations and builds

      // Heap measurement (render delta, scroll delta, data-change delta) is
      // disabled because vm_service cannot reliably connect inside the Flutter
      // test runner. Robust memory profiling requires external tools such as
      // Perfetto or Flutter DevTools during CI/CD. See CLAUDE.md for details.

      expect(find.byType(Worksheet), findsOneWidget);
    });
  });
}
