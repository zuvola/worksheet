import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

/// Spy implementation that records method calls for verification.
class _SpyWorksheetData implements WorksheetData {
  final List<String> calls = [];
  final Map<CellCoordinate, CellValue> _cells = {};
  final Map<CellCoordinate, CellStyle> _styles = {};
  final Map<CellCoordinate, CellFormat> _formats = {};
  final Map<CellCoordinate, List<TextSpan>> _richText = {};
  final _controller = StreamController<DataChangeEvent>.broadcast();
  final _mergedCells = MergedCellRegistry();
  bool disposed = false;

  @override
  int get rowCount => 100;

  @override
  int get columnCount => 50;

  @override
  CellValue? getCell(CellCoordinate coord) {
    calls.add('getCell');
    return _cells[coord];
  }

  @override
  CellStyle? getStyle(CellCoordinate coord) {
    calls.add('getStyle');
    return _styles[coord];
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    calls.add('setCell');
    if (value == null) {
      _cells.remove(coord);
    } else {
      _cells[coord] = value;
    }
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    calls.add('setStyle');
    if (style == null) {
      _styles.remove(coord);
    } else {
      _styles[coord] = style;
    }
  }

  @override
  CellFormat? getFormat(CellCoordinate coord) {
    calls.add('getFormat');
    return _formats[coord];
  }

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {
    calls.add('setFormat');
    if (format == null) {
      _formats.remove(coord);
    } else {
      _formats[coord] = format;
    }
  }

  @override
  List<TextSpan>? getRichText(CellCoordinate coord) {
    calls.add('getRichText');
    return _richText[coord];
  }

  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {
    calls.add('setRichText');
    if (richText == null) {
      _richText.remove(coord);
    } else {
      _richText[coord] = richText;
    }
  }

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) {
    calls.add('batchUpdate');
  }

  @override
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) async {
    calls.add('batchUpdateAsync');
  }

  @override
  Stream<DataChangeEvent> get changes => _controller.stream;

  void emitChange(DataChangeEvent event) => _controller.add(event);

  @override
  bool hasValue(CellCoordinate coord) {
    calls.add('hasValue');
    return _cells.containsKey(coord);
  }

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) {
    calls.add('getCellsInRange');
    return _cells.entries.where((e) => range.contains(e.key));
  }

  @override
  void clearRange(CellRange range) {
    calls.add('clearRange');
  }

  @override
  void clearRichTextInRange(CellRange range) {
    calls.add('clearRichTextInRange');
  }

  @override
  Iterable<MapEntry<CellCoordinate, List<TextSpan>>> getRichTextInRange(
    CellRange range,
  ) {
    calls.add('getRichTextInRange');
    return const [];
  }

  @override
  Iterable<MapEntry<CellCoordinate, CellStyle>> getStylesInRange(
    CellRange range,
  ) {
    calls.add('getStylesInRange');
    return const [];
  }

  @override
  Iterable<MapEntry<CellCoordinate, CellFormat>> getFormatsInRange(
    CellRange range,
  ) {
    calls.add('getFormatsInRange');
    return const [];
  }

  @override
  CellRange? smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    calls.add('smartFill');
    return null;
  }

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    calls.add('fillRange');
  }

  @override
  MergedCellRegistry get mergedCells {
    calls.add('mergedCells');
    return _mergedCells;
  }

  @override
  void mergeCells(CellRange range) {
    calls.add('mergeCells');
  }

  @override
  void unmergeCells(CellCoordinate cell) {
    calls.add('unmergeCells');
  }

  @override
  void unmergeCellsInRange(CellRange range) {
    calls.add('unmergeCellsInRange');
  }

  @override
  void moveMerges(CellRange source, CellCoordinate destination) {
    calls.add('moveMerges');
  }

  @override
  void replicateMerges({
    required CellRange sourceRange,
    required CellRange targetRange,
    required bool vertical,
  }) {
    calls.add('replicateMerges');
  }

  @override
  int? findNextPopulatedRow(int column, int fromRow) {
    calls.add('findNextPopulatedRow');
    return null;
  }

  @override
  int? findPrevPopulatedRow(int column, int fromRow) {
    calls.add('findPrevPopulatedRow');
    return null;
  }

  @override
  int? findNextPopulatedColumn(int row, int fromColumn) {
    calls.add('findNextPopulatedColumn');
    return null;
  }

  @override
  int? findPrevPopulatedColumn(int row, int fromColumn) {
    calls.add('findPrevPopulatedColumn');
    return null;
  }

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}

void main() {
  late _SpyWorksheetData spy;
  late DelegatingWorksheetData wrapper;

  setUp(() {
    spy = _SpyWorksheetData();
    wrapper = DelegatingWorksheetData(spy);
  });

  tearDown(() {
    spy.dispose();
  });

  group('DelegatingWorksheetData', () {
    const coord = CellCoordinate(0, 0);
    final range = CellRange(0, 0, 5, 5);

    test('getCell delegates to inner', () {
      spy._cells[coord] = const CellValue.text('hello');
      expect(wrapper.getCell(coord), const CellValue.text('hello'));
      expect(spy.calls, contains('getCell'));
    });

    test('getStyle delegates to inner', () {
      spy._styles[coord] = const CellStyle(wrapText: true);
      expect(wrapper.getStyle(coord), const CellStyle(wrapText: true));
      expect(spy.calls, contains('getStyle'));
    });

    test('setCell delegates to inner', () {
      wrapper.setCell(coord, CellValue.number(42));
      expect(spy.calls, contains('setCell'));
      expect(spy._cells[coord], CellValue.number(42));
    });

    test('setStyle delegates to inner', () {
      const style = CellStyle(wrapText: true);
      wrapper.setStyle(coord, style);
      expect(spy.calls, contains('setStyle'));
      expect(spy._styles[coord], style);
    });

    test('getFormat delegates to inner', () {
      spy._formats[coord] = CellFormat.currency;
      expect(wrapper.getFormat(coord), CellFormat.currency);
      expect(spy.calls, contains('getFormat'));
    });

    test('setFormat delegates to inner', () {
      wrapper.setFormat(coord, CellFormat.percentage);
      expect(spy.calls, contains('setFormat'));
      expect(spy._formats[coord], CellFormat.percentage);
    });

    test('getRichText delegates to inner', () {
      spy._richText[coord] = const [TextSpan(text: 'hi')];
      final result = wrapper.getRichText(coord);
      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(spy.calls, contains('getRichText'));
    });

    test('setRichText delegates to inner', () {
      wrapper.setRichText(coord, const [TextSpan(text: 'hi')]);
      expect(spy.calls, contains('setRichText'));
      expect(spy._richText[coord], isNotNull);
    });

    test('batchUpdate delegates to inner', () {
      wrapper.batchUpdate((_) {});
      expect(spy.calls, contains('batchUpdate'));
    });

    test('batchUpdateAsync delegates to inner', () async {
      await wrapper.batchUpdateAsync((_) async {});
      expect(spy.calls, contains('batchUpdateAsync'));
    });

    test('changes forwards inner stream', () async {
      final events = <DataChangeEvent>[];
      final sub = wrapper.changes.listen(events.add);

      final event = DataChangeEvent.cellValue(coord);
      spy.emitChange(event);

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.type, DataChangeType.cellValue);

      await sub.cancel();
    });

    test('rowCount delegates to inner', () {
      expect(wrapper.rowCount, 100);
    });

    test('columnCount delegates to inner', () {
      expect(wrapper.columnCount, 50);
    });

    test('hasValue delegates to inner', () {
      spy._cells[coord] = const CellValue.text('x');
      expect(wrapper.hasValue(coord), true);
      expect(spy.calls, contains('hasValue'));
    });

    test('getCellsInRange delegates to inner', () {
      wrapper.getCellsInRange(range);
      expect(spy.calls, contains('getCellsInRange'));
    });

    test('clearRange delegates to inner', () {
      wrapper.clearRange(range);
      expect(spy.calls, contains('clearRange'));
    });

    test('clearRichTextInRange delegates to inner', () {
      wrapper.clearRichTextInRange(range);
      expect(spy.calls, contains('clearRichTextInRange'));
    });

    test('getRichTextInRange delegates to inner', () {
      wrapper.getRichTextInRange(range);
      expect(spy.calls, contains('getRichTextInRange'));
    });

    test('getStylesInRange delegates to inner', () {
      wrapper.getStylesInRange(range);
      expect(spy.calls, contains('getStylesInRange'));
    });

    test('getFormatsInRange delegates to inner', () {
      wrapper.getFormatsInRange(range);
      expect(spy.calls, contains('getFormatsInRange'));
    });

    test('smartFill delegates to inner', () {
      wrapper.smartFill(range, coord);
      expect(spy.calls, contains('smartFill'));
    });

    test('fillRange delegates to inner', () {
      wrapper.fillRange(coord, range);
      expect(spy.calls, contains('fillRange'));
    });

    test('mergedCells delegates to inner', () {
      wrapper.mergedCells;
      expect(spy.calls, contains('mergedCells'));
    });

    test('mergeCells delegates to inner', () {
      wrapper.mergeCells(range);
      expect(spy.calls, contains('mergeCells'));
    });

    test('unmergeCells delegates to inner', () {
      wrapper.unmergeCells(coord);
      expect(spy.calls, contains('unmergeCells'));
    });

    test('unmergeCellsInRange delegates to inner', () {
      wrapper.unmergeCellsInRange(range);
      expect(spy.calls, contains('unmergeCellsInRange'));
    });

    test('moveMerges delegates to inner', () {
      wrapper.moveMerges(range, coord);
      expect(spy.calls, contains('moveMerges'));
    });

    test('replicateMerges delegates to inner', () {
      wrapper.replicateMerges(
        sourceRange: range,
        targetRange: range,
        vertical: true,
      );
      expect(spy.calls, contains('replicateMerges'));
    });

    test('findNextPopulatedRow delegates to inner', () {
      wrapper.findNextPopulatedRow(0, 0);
      expect(spy.calls, contains('findNextPopulatedRow'));
    });

    test('findPrevPopulatedRow delegates to inner', () {
      wrapper.findPrevPopulatedRow(0, 0);
      expect(spy.calls, contains('findPrevPopulatedRow'));
    });

    test('findNextPopulatedColumn delegates to inner', () {
      wrapper.findNextPopulatedColumn(0, 0);
      expect(spy.calls, contains('findNextPopulatedColumn'));
    });

    test('findPrevPopulatedColumn delegates to inner', () {
      wrapper.findPrevPopulatedColumn(0, 0);
      expect(spy.calls, contains('findPrevPopulatedColumn'));
    });

    test('dispose does not dispose inner', () {
      wrapper.dispose();
      expect(spy.disposed, false);
    });
  });

  group('subclass overrides', () {
    test('subclass can override getCell', () {
      final inner = SparseWorksheetData(rowCount: 10, columnCount: 10);
      inner.setCell(const CellCoordinate(0, 0), const CellValue.text('real'));

      final custom = _UpperCaseWrapper(inner);
      final result = custom.getCell(const CellCoordinate(0, 0));
      expect(result, const CellValue.text('REAL'));

      inner.dispose();
    });

    test('subclass can override setCell and call super', () {
      final inner = SparseWorksheetData(rowCount: 10, columnCount: 10);
      final logged = _LoggingWrapper(inner);

      logged.setCell(
        const CellCoordinate(0, 0),
        CellValue.number(42),
      );

      expect(logged.setCellCount, 1);
      expect(
        inner.getCell(const CellCoordinate(0, 0)),
        CellValue.number(42),
      );

      inner.dispose();
    });

    test('subclass can override dispose for cleanup', () {
      final inner = SparseWorksheetData(rowCount: 10, columnCount: 10);
      final custom = _DisposableWrapper(inner);

      custom.dispose();
      expect(custom.cleanedUp, true);
      // inner should NOT be disposed by the wrapper
      // (we can still use it — no exception thrown)
      inner.setCell(const CellCoordinate(0, 0), const CellValue.text('ok'));
      expect(
        inner.getCell(const CellCoordinate(0, 0)),
        const CellValue.text('ok'),
      );

      inner.dispose();
    });
  });
}

/// Example subclass that transforms text values to upper case on read.
class _UpperCaseWrapper extends DelegatingWorksheetData {
  _UpperCaseWrapper(super.inner);

  @override
  CellValue? getCell(CellCoordinate coord) {
    final value = super.getCell(coord);
    if (value == null) return null;
    if (value.isText) {
      return CellValue.text(value.displayValue.toUpperCase());
    }
    return value;
  }
}

/// Example subclass that counts setCell calls.
class _LoggingWrapper extends DelegatingWorksheetData {
  int setCellCount = 0;

  _LoggingWrapper(super.inner);

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    setCellCount++;
    super.setCell(coord, value);
  }
}

/// Example subclass with its own dispose cleanup.
class _DisposableWrapper extends DelegatingWorksheetData {
  bool cleanedUp = false;

  _DisposableWrapper(super.inner);

  @override
  void dispose() {
    cleanedUp = true;
    super.dispose();
  }
}
