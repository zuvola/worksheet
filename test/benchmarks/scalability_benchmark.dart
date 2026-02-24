@Timeout(Duration(seconds: 60))
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/merged_cell_registry.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_value.dart';

/// Benchmark tests for scalability of core data structures.
///
/// Benchmarks:
/// - SpanList Fenwick tree scalability (O(log N) update on resize)
/// - MergedCellRegistry.regionsInRange scalability (O(N_merges) linear scan)
/// - LayoutSolver visible range caching (zero-cost cache hits)
/// - Auto-fit column scalability (dedup + char-length filtering)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpanList Fenwick tree scalability', () {
    test('setSize at 10K spans completes in < 0.1ms', () {
      final spans = SpanList(defaultSize: 24.0, count: 10000);

      // Warm up
      for (int i = 0; i < 10; i++) {
        spans.setSize(i, 30.0);
      }

      final times = <double>[];
      for (int i = 0; i < 50; i++) {
        final sw = Stopwatch()..start();
        spans.setSize(i % 10000, 30.0 + (i % 5));
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('SpanList setSize (10K): ${avg.toStringAsFixed(3)}ms avg');

      expect(avg, lessThan(0.1),
          reason: 'setSize at 10K spans took ${avg.toStringAsFixed(3)}ms avg');
    });

    test('setSize at 100K spans completes in < 0.1ms', () {
      final spans = SpanList(defaultSize: 24.0, count: 100000);

      // Warm up
      for (int i = 0; i < 10; i++) {
        spans.setSize(i, 30.0);
      }

      final times = <double>[];
      for (int i = 0; i < 50; i++) {
        final sw = Stopwatch()..start();
        spans.setSize(i % 100000, 30.0 + (i % 5));
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('SpanList setSize (100K): ${avg.toStringAsFixed(3)}ms avg');

      expect(avg, lessThan(0.1),
          reason:
              'setSize at 100K spans took ${avg.toStringAsFixed(3)}ms avg');
    });

    test('setSize at 1M spans completes in < 1ms', () {
      final spans = SpanList(defaultSize: 24.0, count: 1000000);

      // Warm up
      for (int i = 0; i < 5; i++) {
        spans.setSize(i, 30.0);
      }

      final times = <double>[];
      for (int i = 0; i < 20; i++) {
        final sw = Stopwatch()..start();
        spans.setSize(i % 1000000, 30.0 + (i % 5));
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('SpanList setSize (1M): ${avg.toStringAsFixed(3)}ms avg');

      expect(avg, lessThan(1.0),
          reason: 'setSize at 1M spans took ${avg.toStringAsFixed(3)}ms avg');
    });

    test('construction at 1M spans completes in < 100ms', () {
      final times = <double>[];
      for (int i = 0; i < 10; i++) {
        final sw = Stopwatch()..start();
        SpanList(defaultSize: 24.0, count: 1000000);
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('SpanList construction (1M): ${avg.toStringAsFixed(3)}ms avg');

      expect(avg, lessThan(100.0),
          reason:
              'Construction at 1M spans took ${avg.toStringAsFixed(3)}ms avg');
    });

    test('positionAt at 1M spans: 10K lookups < 5ms', () {
      final spans = SpanList(defaultSize: 24.0, count: 1000000);

      // Add some variable sizes
      for (int i = 0; i < 1000; i++) {
        spans.setSize(i * 1000, 48.0);
      }

      // Warm up
      for (int i = 0; i < 100; i++) {
        spans.positionAt(i * 10000);
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        spans.positionAt(i * 100);
      }
      sw.stop();

      final totalMs = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('positionAt (1M, 10K lookups): ${totalMs.toStringAsFixed(3)}ms');

      expect(totalMs, lessThan(5.0),
          reason: '10K positionAt lookups took ${totalMs.toStringAsFixed(3)}ms');
    });

    test('indexAtPosition at 1M spans: 10K lookups < 10ms', () {
      final spans = SpanList(defaultSize: 24.0, count: 1000000);

      // Add some variable sizes
      for (int i = 0; i < 1000; i++) {
        spans.setSize(i * 1000, 48.0);
      }

      final total = spans.totalSize;

      // Warm up
      for (int i = 0; i < 100; i++) {
        spans.indexAtPosition(total * i / 100);
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        spans.indexAtPosition(total * i / 10000);
      }
      sw.stop();

      final totalMs = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print(
          'indexAtPosition (1M, 10K lookups): ${totalMs.toStringAsFixed(3)}ms');

      expect(totalMs, lessThan(10.0),
          reason:
              '10K indexAtPosition lookups took ${totalMs.toStringAsFixed(3)}ms');
    });
  });

  group('MergedCellRegistry.regionsInRange scalability', () {
    /// Creates [count] non-overlapping 2x2 merges, distributed across the
    /// grid. Returns the registry and the total grid rows used.
    (MergedCellRegistry, int) createRegistry(int count) {
      final registry = MergedCellRegistry();
      // Place 2x2 merges in rows spaced 3 apart, columns spaced 3 apart
      // Grid: ceil(sqrt(count)) columns of merges
      final cols = 100; // 100 merge columns
      for (int i = 0; i < count; i++) {
        final mr = (i ~/ cols) * 3;
        final mc = (i % cols) * 3;
        registry.merge(CellRange(mr, mc, mr + 1, mc + 1));
      }
      final totalRows = ((count ~/ cols) + 1) * 3;
      return (registry, totalRows);
    }

    test('regionsInRange with 100 merges completes in < 0.5ms', () {
      final (registry, _) = createRegistry(100);

      // Warm up
      for (int i = 0; i < 10; i++) {
        registry.regionsInRange(const CellRange(0, 0, 49, 49));
      }

      final times = <double>[];
      for (int i = 0; i < 100; i++) {
        final sw = Stopwatch()..start();
        registry.regionsInRange(CellRange(0, 0, 49, 49));
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('regionsInRange (100 merges): ${avg.toStringAsFixed(3)}ms avg');

      expect(avg, lessThan(0.5),
          reason: 'regionsInRange with 100 merges took '
              '${avg.toStringAsFixed(3)}ms avg');
    });

    test('regionsInRange with 1K merges completes in < 5ms', () {
      final (registry, _) = createRegistry(1000);

      // Warm up
      for (int i = 0; i < 10; i++) {
        registry.regionsInRange(const CellRange(0, 0, 49, 49));
      }

      final times = <double>[];
      for (int i = 0; i < 100; i++) {
        final sw = Stopwatch()..start();
        registry.regionsInRange(CellRange(0, 0, 49, 49));
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('regionsInRange (1K merges): ${avg.toStringAsFixed(3)}ms avg');

      // O(N_merges) linear scan — acceptable up to ~1K merges
      expect(avg, lessThan(5.0),
          reason: 'regionsInRange with 1K merges took '
              '${avg.toStringAsFixed(3)}ms avg');
    });

    test('regionsInRange with 10K merges completes in < 50ms', () {
      final (registry, _) = createRegistry(10000);

      // Warm up
      for (int i = 0; i < 5; i++) {
        registry.regionsInRange(const CellRange(0, 0, 49, 49));
      }

      final times = <double>[];
      for (int i = 0; i < 50; i++) {
        final sw = Stopwatch()..start();
        registry.regionsInRange(CellRange(0, 0, 49, 49));
        sw.stop();
        times.add(sw.elapsedMicroseconds / 1000.0);
      }

      final avg = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('regionsInRange (10K merges): ${avg.toStringAsFixed(3)}ms avg');

      // O(N_merges) linear scan — documents cost at 10K scale.
      // Consider R-tree if this becomes a bottleneck.
      expect(avg, lessThan(50.0),
          reason: 'regionsInRange with 10K merges took '
              '${avg.toStringAsFixed(3)}ms avg');
    });
  });

  group('LayoutSolver visible range caching', () {
    late LayoutSolver solver;

    setUp(() {
      final rows = SpanList(defaultSize: 24.0, count: 100000);
      final columns = SpanList(defaultSize: 80.0, count: 1000);

      // Add some variable sizes to make binary search non-trivial
      for (int i = 0; i < 1000; i++) {
        rows.setSize(i * 100, 48.0);
      }
      for (int i = 0; i < 100; i++) {
        columns.setSize(i * 10, 120.0);
      }

      solver = LayoutSolver(rows: rows, columns: columns);
    });

    test('1000 repeated identical lookups complete in < 1ms total', () {
      const scrollY = 5000.0;
      const scrollX = 2000.0;
      const viewportHeight = 800.0;
      const viewportWidth = 1200.0;

      // Warm up
      for (int i = 0; i < 50; i++) {
        solver.getVisibleRows(scrollY, viewportHeight);
        solver.getVisibleColumns(scrollX, viewportWidth);
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        solver.getVisibleRows(scrollY, viewportHeight);
        solver.getVisibleColumns(scrollX, viewportWidth);
      }
      sw.stop();

      final totalMs = sw.elapsedMicroseconds / 1000.0;
      final perCallUs = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('1000 repeated lookups: ${totalMs.toStringAsFixed(3)}ms total '
          '(${perCallUs.toStringAsFixed(3)}us per call)');

      // Cache hits are near-zero cost
      expect(totalMs, lessThan(1.0),
          reason:
              '1000 repeated lookups took ${totalMs.toStringAsFixed(3)}ms');
    });

    test('1000 sequential scroll positions complete with < 50us avg per frame',
        () {
      const viewportHeight = 800.0;
      const viewportWidth = 1200.0;
      final maxScrollY = solver.totalHeight - viewportHeight;
      final scrollStep = maxScrollY / 1000;

      // Warm up
      for (int i = 0; i < 50; i++) {
        solver.getVisibleRows(i * scrollStep, viewportHeight);
        solver.getVisibleColumns(0, viewportWidth);
      }

      final times = <int>[];
      for (int i = 0; i < 1000; i++) {
        final scrollY = i * scrollStep;
        final sw = Stopwatch()..start();
        solver.getVisibleRows(scrollY, viewportHeight);
        solver.getVisibleColumns(0, viewportWidth);
        sw.stop();
        times.add(sw.elapsedMicroseconds);
      }

      final avgUs = times.reduce((a, b) => a + b) / times.length;
      // ignore: avoid_print
      print('Sequential scroll: ${avgUs.toStringAsFixed(1)}us avg per frame');

      // Fenwick tree O(log N) lookups — fast enough for sequential scrolling
      expect(avgUs, lessThan(50),
          reason:
              'Per-frame visible range took ${avgUs.toStringAsFixed(1)}us avg');
    });
  });

  group('Auto-fit column scalability', () {
    /// Replicates the optimized auto-fit measurement pattern used by
    /// _autoFitColumn: iterate cells, dedup by display value, filter to
    /// max character length, measure only the candidates with TextPainter.
    double measureAutoFit(SparseWorksheetData data, int column, int rowCount) {
      const baseTextStyle = TextStyle(fontSize: 11.0);

      int maxCharLen = 0;
      final plainCandidates = <String>{};
      final richCandidates = <String, List<TextSpan>>{};

      final range = CellRange(0, column, rowCount - 1, column);
      for (final entry in data.getCellsInRange(range)) {
        final text = entry.value.displayValue;
        if (text.isEmpty) continue;

        final richText = data.getRichText(entry.key);
        if (richText != null && richText.isNotEmpty) {
          richCandidates.putIfAbsent(text, () => richText);
          continue;
        }

        if (text.length > maxCharLen) {
          maxCharLen = text.length;
          plainCandidates.clear();
          plainCandidates.add(text);
        } else if (text.length == maxCharLen) {
          plainCandidates.add(text);
        }
      }

      double maxWidth = 0.0;
      int measured = 0;
      for (final text in plainCandidates) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: baseTextStyle),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        if (tp.width > maxWidth) maxWidth = tp.width;
        tp.dispose();
        if (++measured >= 1000) break;
      }

      for (final entry in richCandidates.entries) {
        final tp = TextPainter(
          text: TextSpan(style: baseTextStyle, children: entry.value),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        if (tp.width > maxWidth) maxWidth = tp.width;
        tp.dispose();
      }

      return maxWidth;
    }

    test('auto-fit 50K-cell column with few unique values < 200ms', () {
      // Mimics the example app's Customer column: 50K rows, 16 unique values
      final data = SparseWorksheetData(rowCount: 50001, columnCount: 14);
      final customers = [
        'Acme Corp', 'TechStart Inc', 'Global Industries', 'Smith & Co',
        'Johnson LLC', 'Pacific Trading', 'Atlantic Imports',
        'Central Services', 'Northern Supplies', 'Southern Distribution',
        'Eastern Partners', 'Western Logistics', 'Metro Solutions',
        'Urban Enterprises', 'Rural Products', 'Coastal Goods',
      ];
      final random = math.Random(42);
      for (var row = 1; row <= 50000; row++) {
        data.setCell(
          CellCoordinate(row, 2),
          CellValue.text(customers[random.nextInt(customers.length)]),
        );
      }

      // Warm up
      measureAutoFit(data, 2, 50001);

      final sw = Stopwatch()..start();
      final maxWidth = measureAutoFit(data, 2, 50001);
      sw.stop();

      final ms = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Auto-fit 50K cells (16 unique): ${ms.toStringAsFixed(1)}ms');

      expect(ms, lessThan(200.0),
          reason: 'Auto-fit 50K cells (16 unique) took ${ms.toStringAsFixed(1)}ms');
      expect(maxWidth, greaterThan(0.0));
      data.dispose();
    });

    test('auto-fit 50K-cell column with many unique values < 200ms', () {
      // Mimics the example app's ID column: 50K rows, all unique sequential IDs
      final data = SparseWorksheetData(rowCount: 50001, columnCount: 14);
      for (var row = 1; row <= 50000; row++) {
        data.setCell(
          CellCoordinate(row, 0),
          CellValue.number(row.toDouble()),
        );
      }

      // Warm up
      measureAutoFit(data, 0, 50001);

      final sw = Stopwatch()..start();
      final maxWidth = measureAutoFit(data, 0, 50001);
      sw.stop();

      final ms = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Auto-fit 50K cells (unique IDs): ${ms.toStringAsFixed(1)}ms');

      expect(ms, lessThan(200.0),
          reason: 'Auto-fit 50K cells (unique IDs) took ${ms.toStringAsFixed(1)}ms');
      expect(maxWidth, greaterThan(0.0));
      data.dispose();
    });

    test('auto-fit 50K-cell column with rich text < 200ms', () {
      // Mimics the example app's Status column: 50K rows, 5 statuses,
      // ~10K "Cancelled" cells have rich text (bold + red)
      final data = SparseWorksheetData(rowCount: 50001, columnCount: 14);
      final statuses = ['Completed', 'Pending', 'Shipped', 'Processing', 'Cancelled'];
      final random = math.Random(42);
      for (var row = 1; row <= 50000; row++) {
        final status = statuses[random.nextInt(statuses.length)];
        data.setCell(CellCoordinate(row, 11), CellValue.text(status));
        if (status == 'Cancelled') {
          data.setRichText(CellCoordinate(row, 11), const [
            TextSpan(
              text: 'Cancelled',
              style: TextStyle(
                color: Color(0xFFCC0000),
                fontWeight: FontWeight.bold,
              ),
            ),
          ]);
        }
      }

      // Warm up
      measureAutoFit(data, 11, 50001);

      final sw = Stopwatch()..start();
      final maxWidth = measureAutoFit(data, 11, 50001);
      sw.stop();

      final ms = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Auto-fit 50K cells (rich text): ${ms.toStringAsFixed(1)}ms');

      expect(ms, lessThan(200.0),
          reason: 'Auto-fit 50K cells (rich text) took ${ms.toStringAsFixed(1)}ms');
      expect(maxWidth, greaterThan(0.0));
      data.dispose();
    });
  });

  group('Jump-to-edge scalability', () {
    test('jump across 1M empty rows < 200ms', () {
      // Column with data at rows 0-50000 and nothing beyond.
      // Jump UP from row 1048575 to find row 50000.
      final data = SparseWorksheetData(rowCount: 1048576, columnCount: 16384);
      for (var row = 0; row <= 50000; row++) {
        data.setCell(
          CellCoordinate(row, 3),
          CellValue.text('Row $row'),
        );
      }

      // Warm up
      data.findPrevPopulatedRow(3, 1048575);

      final sw = Stopwatch()..start();
      final result = data.findPrevPopulatedRow(3, 1048575);
      sw.stop();

      final ms = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Jump UP across 1M empty rows: ${ms.toStringAsFixed(1)}ms');

      expect(result, 50000);
      expect(ms, lessThan(200.0),
          reason: 'Jump across 1M empty rows took ${ms.toStringAsFixed(1)}ms');
      data.dispose();
    });

    test('jump across 16K empty columns < 200ms', () {
      // Row with data at column 0 and column 16383.
      // Jump RIGHT from column 0+1 to find column 16383.
      final data = SparseWorksheetData(rowCount: 1048576, columnCount: 16384);
      data.setCell(CellCoordinate(5, 0), CellValue.text('Start'));
      data.setCell(CellCoordinate(5, 16383), CellValue.text('End'));

      // Warm up
      data.findNextPopulatedColumn(5, 1);

      final sw = Stopwatch()..start();
      final result = data.findNextPopulatedColumn(5, 1);
      sw.stop();

      final ms = sw.elapsedMicroseconds / 1000.0;
      // ignore: avoid_print
      print('Jump RIGHT across 16K empty columns: ${ms.toStringAsFixed(1)}ms');

      expect(result, 16383);
      expect(ms, lessThan(200.0),
          reason:
              'Jump across 16K empty columns took ${ms.toStringAsFixed(1)}ms');
      data.dispose();
    });
  });
}
