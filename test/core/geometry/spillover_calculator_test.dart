import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/spillover_calculator.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('SpilloverCalculator', () {
    late SparseWorksheetData data;
    late LayoutSolver layoutSolver;

    setUp(() {
      data = SparseWorksheetData(rowCount: 100, columnCount: 20);
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 20, defaultSize: 100.0),
      );
    });

    tearDown(() {
      data.dispose();
    });

    test('no spillover when text fits within cell', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 50.0, // fits in 100 - 2*4 = 92 available
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.startColumn, 0);
      expect(result.endColumn, 0);
      expect(result.showHashFill, false);
      expect(result.hasSpillover, false);
    });

    test('no spillover when wrapText is true', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0, // overflows
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: true,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.hasSpillover, false);
      expect(result.showHashFill, false);
    });

    test('left-aligned text spills right into empty cells', () {
      // textWidth 250 > available 92, excess ~158, needs 2 more columns (100 each)
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 250.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.startColumn, 0);
      expect(result.endColumn, 2);
      expect(result.hasSpillover, true);
      expect(result.showHashFill, false);
      // totalWidth = 100 (col 0) + 100 (col 1) + 100 (col 2) = 300
      expect(result.totalWidth, 300.0);
    });

    test('right-aligned text spills left into empty cells', () {
      // Put text in column 3, spill left
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 3,
        textWidth: 250.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.startColumn, 1);
      expect(result.endColumn, 3);
      expect(result.hasSpillover, true);
      expect(result.showHashFill, false);
      expect(result.totalWidth, 300.0);
    });

    test('center-aligned text spills both directions', () {
      // Center in column 5, excess splits both ways
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 5,
        textWidth: 250.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.center,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.hasSpillover, true);
      expect(result.startColumn, lessThan(5));
      expect(result.endColumn, greaterThan(5));
      expect(result.showHashFill, false);
    });

    test('spillover stops at non-empty cell on the right', () {
      data.setCell(const CellCoordinate(0, 2), const CellValue.text('Block'));

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 350.0, // wants to spill far right
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      // Should stop at column 1 (column 2 has data)
      expect(result.endColumn, 1);
      expect(result.startColumn, 0);
    });

    test('spillover stops at non-empty cell on the left', () {
      data.setCell(const CellCoordinate(0, 1), const CellValue.text('Block'));

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 3,
        textWidth: 350.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      // Should stop at column 2 (column 1 has data)
      expect(result.startColumn, 2);
      expect(result.endColumn, 3);
    });

    test('spillover stops at merged cell region', () {
      data.mergeCells(const CellRange(0, 2, 0, 3));
      layoutSolver.mergedCells = data.mergedCells;

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 500.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        mergedCells: data.mergedCells,
        maxColumn: 19,
      );

      // Should stop at column 1 (column 2 is part of merge)
      expect(result.endColumn, 1);
    });

    test('spillover stops at sheet right edge', () {
      // Use small sheet
      final smallData = SparseWorksheetData(rowCount: 10, columnCount: 3);
      final smallLayout = LayoutSolver(
        rows: SpanList(count: 10, defaultSize: 24.0),
        columns: SpanList(count: 3, defaultSize: 100.0),
      );

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 1,
        textWidth: 500.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: smallData,
        layoutSolver: smallLayout,
        maxColumn: 2,
      );

      expect(result.endColumn, 2);
      smallData.dispose();
    });

    test('spillover stops at sheet left edge', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 1,
        textWidth: 500.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.startColumn, 0);
    });

    test('number overflow shows hashFill', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.number,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.showHashFill, true);
      expect(result.hasSpillover, false);
    });

    test('date overflow shows hashFill', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.date,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.showHashFill, true);
    });

    test('duration overflow shows hashFill', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.duration,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.showHashFill, true);
    });

    test('boolean overflow shows hashFill', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.right,
        valueType: CellValueType.boolean,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.showHashFill, true);
    });

    test('text overflow does NOT show hashFill', () {
      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      expect(result.showHashFill, false);
      expect(result.hasSpillover, true);
    });

    test('multi-column spillover accumulates widths correctly', () {
      // Make columns different widths
      layoutSolver.setColumnWidth(1, 50.0);
      layoutSolver.setColumnWidth(2, 75.0);
      layoutSolver.setColumnWidth(3, 120.0);

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 300.0, // excess = 300 - 92 = 208
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      // col 0: 100, col 1: 50 (total 150), col 2: 75 (total 225),
      // col 3: 120 (total 345) — need 300+8=308 total for text+padding
      // After col 2: 225 < 308, after col 3: 345 >= 308
      expect(result.endColumn, 3);
      expect(result.totalWidth, 345.0);
    });

    test('merged cell source spills from merge edge', () {
      // Merge columns 0-1 in row 0
      data.mergeCells(const CellRange(0, 0, 0, 1));
      layoutSolver.mergedCells = data.mergedCells;

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 350.0,
        cellWidth: 200.0, // merged width of 2 columns
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        mergedCells: data.mergedCells,
        maxColumn: 19,
      );

      // Merge occupies cols 0-1, spillover should extend from col 2 onward
      expect(result.startColumn, 0);
      expect(result.endColumn, greaterThan(1));
      expect(result.hasSpillover, true);
    });

    test('no spillover when all adjacent cells are occupied', () {
      data.setCell(const CellCoordinate(0, 1), const CellValue.text('Block'));

      final result = SpilloverCalculator.compute(
        row: 0,
        column: 0,
        textWidth: 200.0,
        cellWidth: 100.0,
        cellPadding: 4.0,
        alignment: CellTextAlignment.left,
        valueType: CellValueType.text,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        maxColumn: 19,
      );

      // Blocked immediately — no spillover
      expect(result.hasSpillover, false);
      expect(result.startColumn, 0);
      expect(result.endColumn, 0);
    });
  });
}
