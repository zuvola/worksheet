import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  group('UndoSnapshot', () {
    late SparseWorksheetData data;

    setUp(() {
      data = SparseWorksheetData(rowCount: 10, columnCount: 10);
    });

    tearDown(() => data.dispose());

    test('capture captures values', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Hello'));
      data.setCell(const CellCoordinate(1, 0), CellValue.number(42));

      final (cells, merges) = UndoSnapshot.capture(
        data,
        const CellRange(0, 0, 1, 0),
      );

      expect(cells.length, 2);
      expect(
        cells[const CellCoordinate(0, 0)]!.value,
        const CellValue.text('Hello'),
      );
      expect(cells[const CellCoordinate(1, 0)]!.value, CellValue.number(42));
      expect(merges, isEmpty);
    });

    test('capture captures styles', () {
      const style = CellStyle(backgroundColor: Color(0xFFFF0000));
      data.setStyle(const CellCoordinate(0, 0), style);

      final (cells, _) = UndoSnapshot.capture(
        data,
        const CellRange(0, 0, 0, 0),
      );

      expect(cells[const CellCoordinate(0, 0)]!.style, style);
    });

    test('capture captures formats', () {
      final format = CellFormat.currency;
      data.setFormat(const CellCoordinate(0, 0), format);

      final (cells, _) = UndoSnapshot.capture(
        data,
        const CellRange(0, 0, 0, 0),
      );

      expect(cells[const CellCoordinate(0, 0)]!.format, format);
    });

    test('capture captures rich text', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('bold'));
      data.setRichText(const CellCoordinate(0, 0), [
        const TextSpan(
          text: 'bold',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);

      final (cells, _) = UndoSnapshot.capture(
        data,
        const CellRange(0, 0, 0, 0),
      );

      expect(cells[const CellCoordinate(0, 0)]!.richText, isNotNull);
      expect(cells[const CellCoordinate(0, 0)]!.richText!.length, 1);
    });

    test('capture captures merge regions', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Merged'));
      data.mergeCells(const CellRange(0, 0, 1, 1));

      final (_, merges) = UndoSnapshot.capture(
        data,
        const CellRange(0, 0, 1, 1),
      );

      expect(merges.length, 1);
      expect(merges[0], const CellRange(0, 0, 1, 1));
    });

    test('capture builds combined Cell from value + style + format', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Hi'));
      const style = CellStyle(backgroundColor: Color(0xFF00FF00));
      data.setStyle(const CellCoordinate(0, 0), style);
      final format = CellFormat.percentage;
      data.setFormat(const CellCoordinate(0, 0), format);

      final (cells, _) = UndoSnapshot.capture(
        data,
        const CellRange(0, 0, 0, 0),
      );

      final cell = cells[const CellCoordinate(0, 0)]!;
      expect(cell.value, const CellValue.text('Hi'));
      expect(cell.style, style);
      expect(cell.format, format);
    });

    test('capture returns empty map for empty range', () {
      final (cells, merges) = UndoSnapshot.capture(
        data,
        const CellRange(5, 5, 7, 7),
      );
      expect(cells, isEmpty);
      expect(merges, isEmpty);
    });

    test('restore round-trip preserves values', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('A'));
      data.setCell(const CellCoordinate(0, 1), CellValue.number(10));
      const range = CellRange(0, 0, 0, 1);

      final (cells, merges) = UndoSnapshot.capture(data, range);

      // Clear original data
      data.clearRange(range);
      expect(data.getCell(const CellCoordinate(0, 0)), isNull);

      // Restore
      UndoSnapshot.restore(data, range, cells, merges);
      expect(
        data.getCell(const CellCoordinate(0, 0)),
        const CellValue.text('A'),
      );
      expect(data.getCell(const CellCoordinate(0, 1)), CellValue.number(10));
    });

    test('restore round-trip preserves styles', () {
      const style = CellStyle(backgroundColor: Color(0xFFFF0000));
      data.setStyle(const CellCoordinate(0, 0), style);
      const range = CellRange(0, 0, 0, 0);

      final (cells, merges) = UndoSnapshot.capture(data, range);
      data.clearRange(range);
      UndoSnapshot.restore(data, range, cells, merges);

      expect(data.getStyle(const CellCoordinate(0, 0)), style);
    });

    test('restore round-trip preserves formats', () {
      final format = CellFormat.currency;
      data.setFormat(const CellCoordinate(0, 0), format);
      const range = CellRange(0, 0, 0, 0);

      final (cells, merges) = UndoSnapshot.capture(data, range);
      data.clearRange(range);
      UndoSnapshot.restore(data, range, cells, merges);

      expect(data.getFormat(const CellCoordinate(0, 0)), format);
    });

    test('restore round-trip preserves rich text', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('hi'));
      data.setRichText(const CellCoordinate(0, 0), [
        const TextSpan(
          text: 'hi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);
      const range = CellRange(0, 0, 0, 0);

      final (cells, merges) = UndoSnapshot.capture(data, range);
      data.clearRange(range);
      UndoSnapshot.restore(data, range, cells, merges);

      final rt = data.getRichText(const CellCoordinate(0, 0));
      expect(rt, isNotNull);
      expect(rt!.length, 1);
      expect(rt[0].text, 'hi');
    });

    test('restore round-trip preserves merges', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('M'));
      data.mergeCells(const CellRange(0, 0, 1, 1));
      const range = CellRange(0, 0, 1, 1);

      final (cells, merges) = UndoSnapshot.capture(data, range);

      // Destroy the data
      data.unmergeCellsInRange(range);
      data.clearRange(range);

      // Restore
      UndoSnapshot.restore(data, range, cells, merges);

      final region = data.mergedCells.getRegion(const CellCoordinate(0, 0));
      expect(region, isNotNull);
      expect(region!.range, const CellRange(0, 0, 1, 1));
    });

    test('restore clears existing data before writing', () {
      // Set some data in a range
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Old'));
      data.setCell(const CellCoordinate(0, 1), const CellValue.text('Extra'));

      // Capture a snapshot with only one cell
      final snapshot = <CellCoordinate, Cell>{
        const CellCoordinate(0, 0): const Cell(value: CellValue.text('New')),
      };

      UndoSnapshot.restore(data, const CellRange(0, 0, 0, 1), snapshot, []);

      expect(
        data.getCell(const CellCoordinate(0, 0)),
        const CellValue.text('New'),
      );
      // (0, 1) should be cleared since it wasn't in the snapshot
      expect(data.getCell(const CellCoordinate(0, 1)), isNull);
    });
  });
}
