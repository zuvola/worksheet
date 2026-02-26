import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/data_change_event.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

void main() {
  group('Change notification coalescing', () {
    late SparseWorksheetData data;

    setUp(() {
      data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    });

    tearDown(() {
      data.dispose();
    });

    group('individual calls emit separate events', () {
      test('setCell + setFormat + setRichText emits 3 events', () async {
        final coord = CellCoordinate(0, 0);

        // Use stream matchers to reliably collect all async events.
        final future = expectLater(
          data.changes,
          emitsInOrder([
            isA<DataChangeEvent>()
                .having((e) => e.type, 'type', DataChangeType.cellValue)
                .having((e) => e.cell, 'cell', coord),
            isA<DataChangeEvent>()
                .having((e) => e.type, 'type', DataChangeType.cellFormat)
                .having((e) => e.cell, 'cell', coord),
            isA<DataChangeEvent>()
                .having((e) => e.type, 'type', DataChangeType.cellValue)
                .having((e) => e.cell, 'cell', coord),
          ]),
        );

        data.setCell(coord, CellValue.number(42));
        data.setFormat(coord, CellFormat.currency);
        data.setRichText(coord, const [TextSpan(text: '42')]);

        await future;
      });
    });

    group('batchUpdate emits a single event', () {
      test(
        'setCell + setFormat + setRichText in batch emits 1 event',
        () async {
          final coord = CellCoordinate(0, 0);

          final future = expectLater(
            data.changes,
            emits(
              isA<DataChangeEvent>().having(
                (e) => e.type,
                'type',
                DataChangeType.range,
              ),
            ),
          );

          data.batchUpdate((batch) {
            batch.setCell(coord, CellValue.number(42));
            batch.setFormat(coord, CellFormat.currency);
            batch.setRichText(coord, const [TextSpan(text: '42')]);
          });

          await future;
        },
      );

      test('batch range covers the modified coordinate', () async {
        final coord = CellCoordinate(5, 3);

        final future = expectLater(
          data.changes,
          emits(
            isA<DataChangeEvent>().having(
              (e) => e.type,
              'type',
              DataChangeType.range,
            ),
          ),
        );

        data.batchUpdate((batch) {
          batch.setCell(coord, CellValue.text('hello'));
          batch.setFormat(coord, CellFormat.percentage);
        });

        await future;

        // Re-subscribe and verify via a direct check: the range event
        // was already matched above; verify the range coordinates by
        // collecting it fresh.
        final events = <DataChangeEvent>[];
        data.changes.listen(events.add);
        data.batchUpdate((batch) {
          batch.setCell(coord, CellValue.text('world'));
        });
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        final range = events[0].range!;
        expect(range.startRow, lessThanOrEqualTo(5));
        expect(range.endRow, greaterThanOrEqualTo(5));
        expect(range.startColumn, lessThanOrEqualTo(3));
        expect(range.endColumn, greaterThanOrEqualTo(3));
      });

      test('batch range covers multiple modified coordinates', () async {
        final future = expectLater(
          data.changes,
          emits(
            isA<DataChangeEvent>()
                .having((e) => e.type, 'type', DataChangeType.range)
                .having((e) => e.range!.startRow, 'startRow', 0)
                .having((e) => e.range!.startColumn, 'startColumn', 0)
                .having((e) => e.range!.endRow, 'endRow', 10)
                .having((e) => e.range!.endColumn, 'endColumn', 5),
          ),
        );

        data.batchUpdate((batch) {
          batch.setCell(CellCoordinate(0, 0), CellValue.text('a'));
          batch.setCell(CellCoordinate(10, 5), CellValue.text('b'));
        });

        await future;
      });
    });
  });
}
