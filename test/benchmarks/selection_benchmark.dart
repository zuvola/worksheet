@Timeout(Duration(seconds: 30))
library;

import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_handler.dart';
import 'package:worksheet/src/interaction/clipboard/clipboard_serializer.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/shortcuts/worksheet_actions.dart';
import 'package:worksheet/src/shortcuts/worksheet_intents.dart';

import '../helpers/mock_worksheet_action_context.dart';

/// Excel-scale dimensions.
const _excelRows = 1048576;
const _excelCols = 16384;

/// Full-sheet selection range.
const _fullSheet = CellRange(0, 0, _excelRows - 1, _excelCols - 1);

/// Benchmark tests for selection and action performance at Excel scale.
///
/// Ensures that operations on large selections complete in bounded time
/// by iterating sparse data instead of the full cartesian product.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SparseWorksheetData data;
  late SelectionController selectionController;
  late ClipboardHandler clipboardHandler;
  late MockWorksheetActionContext ctx;

  /// Populates [data] with sparse cells spread across the full Excel grid.
  void populateExcelScaleData() {
    final rng = Random(42);
    // 50K values scattered across the grid
    for (int i = 0; i < 50000; i++) {
      final row = rng.nextInt(_excelRows);
      final col = rng.nextInt(_excelCols);
      final coord = CellCoordinate(row, col);
      data.setCell(coord, CellValue.text('v$i'));
    }
    // ~10K rich text (on existing cells)
    int richCount = 0;
    for (final entry in data.getCellsInRange(_fullSheet)) {
      if (richCount >= 10000) break;
      data.setRichText(entry.key, [
        TextSpan(
          text: entry.value.displayValue,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);
      richCount++;
    }
    // ~16K styles
    int styleCount = 0;
    for (final entry in data.getCellsInRange(_fullSheet)) {
      if (styleCount >= 16000) break;
      data.setStyle(
        entry.key,
        const CellStyle(backgroundColor: Color(0xFFEEEEEE)),
      );
      styleCount++;
    }
  }

  setUp(() {
    data = SparseWorksheetData(rowCount: _excelRows, columnCount: _excelCols);
    selectionController = SelectionController();
    clipboardHandler = ClipboardHandler(
      data: data,
      selectionController: selectionController,
      serializer: const TsvClipboardSerializer(),
    );
    ctx = MockWorksheetActionContext(
      selectionController: selectionController,
      maxRow: _excelRows,
      maxColumn: _excelCols,
      worksheetData: data,
      clipboardHandler: clipboardHandler,
    );
    populateExcelScaleData();
    // Select the full sheet
    selectionController.selectRange(_fullSheet);
  });

  tearDown(() {
    selectionController.dispose();
    data.dispose();
  });

  group('SelectionController at Excel scale', () {
    test('selectRange completes in < 1ms', () {
      final sw = Stopwatch()..start();
      selectionController.selectRange(_fullSheet);
      sw.stop();
      expect(
        sw.elapsedMicroseconds,
        lessThan(1000),
        reason: 'selectRange should be O(1), took ${sw.elapsedMicroseconds}us',
      );
    });

    test('selectRow completes in < 1ms', () {
      final sw = Stopwatch()..start();
      selectionController.selectRange(
        CellRange(500000, 0, 500000, _excelCols - 1),
      );
      sw.stop();
      expect(sw.elapsedMicroseconds, lessThan(1000));
    });

    test('selectColumn completes in < 1ms', () {
      final sw = Stopwatch()..start();
      selectionController.selectRange(CellRange(0, 8000, _excelRows - 1, 8000));
      sw.stop();
      expect(sw.elapsedMicroseconds, lessThan(1000));
    });
  });

  group('SparseWorksheetData at Excel scale', () {
    test('clearRange on full sheet completes in < 200ms', () {
      final sw = Stopwatch()..start();
      data.clearRange(_fullSheet);
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'clearRange took ${sw.elapsedMilliseconds}ms',
      );
    });

    test('clearRichTextInRange on full sheet completes in < 200ms', () {
      final sw = Stopwatch()..start();
      data.clearRichTextInRange(_fullSheet);
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'clearRichTextInRange took ${sw.elapsedMilliseconds}ms',
      );
    });

    test('getStylesInRange on full sheet completes in < 200ms', () {
      final sw = Stopwatch()..start();
      final styles = data.getStylesInRange(_fullSheet).toList();
      sw.stop();
      expect(styles.length, greaterThan(0));
      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'getStylesInRange took ${sw.elapsedMilliseconds}ms',
      );
    });
  });

  group('ClearCellsAction at Excel scale', () {
    test('clearStyle on full sheet completes in < 200ms', () {
      final action = ClearCellsAction(ctx);
      final sw = Stopwatch()..start();
      action.invoke(
        const ClearCellsIntent(
          clearValue: false,
          clearStyle: true,
          clearFormat: false,
        ),
      );
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'ClearCellsAction(clearStyle) took ${sw.elapsedMilliseconds}ms',
      );
    });
  });

  group('ToggleBoldAction at Excel scale', () {
    test('toggle bold on full sheet completes in < 200ms', () {
      final action = ToggleBoldAction(ctx);
      final sw = Stopwatch()..start();
      action.invoke(const ToggleBoldIntent());
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'ToggleBoldAction took ${sw.elapsedMilliseconds}ms',
      );
    });
  });

  group('SetCellStyleAction at Excel scale', () {
    test('set background color on full sheet completes in < 200ms', () {
      final action = SetCellStyleAction(ctx);
      final sw = Stopwatch()..start();
      action.invoke(
        const SetCellStyleIntent(CellStyle(backgroundColor: Color(0xFFFF0000))),
      );
      sw.stop();
      expect(
        sw.elapsedMilliseconds,
        lessThan(200),
        reason: 'SetCellStyleAction took ${sw.elapsedMilliseconds}ms',
      );
    });
  });

  group('Clipboard serialize at Excel scale', () {
    test('serialize full sheet completes in < 500ms', () {
      const serializer = TsvClipboardSerializer();
      final sw = Stopwatch()..start();
      final result = serializer.serialize(_fullSheet, data);
      sw.stop();
      expect(result.isNotEmpty, isTrue);
      expect(
        sw.elapsedMilliseconds,
        lessThan(500),
        reason: 'Clipboard serialize took ${sw.elapsedMilliseconds}ms',
      );
    });
  });

  group('fillRangeWithCell guard', () {
    test('throws StateError for ranges > 1M cells', () {
      expect(
        () => data.batchUpdate((batch) {
          batch.fillRangeWithCell(_fullSheet, null);
        }),
        throwsStateError,
      );
    });

    test('allows ranges <= 1M cells', () {
      final smallRange = CellRange(0, 0, 999, 999); // 1M cells
      expect(
        () => data.batchUpdate((batch) {
          batch.fillRangeWithCell(smallRange, null);
        }),
        returnsNormally,
      );
    });
  });
}
