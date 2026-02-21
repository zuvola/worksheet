@Timeout(Duration(seconds: 60))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/merged_cell_registry.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

/// Benchmark tests for scalability of core data structures.
///
/// Covers three TECH_DEBT items:
/// - SpanList._rebuildCumulative scalability (O(N) rebuild on resize)
/// - MergedCellRegistry.regionsInRange scalability (O(N_merges) linear scan)
/// - LayoutSolver visible range repeated calculations (binary search per call)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpanList._rebuildCumulative scalability', () {
    test('setSize at 10K spans completes in < 1ms', () {
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

      expect(avg, lessThan(1.0),
          reason: 'setSize at 10K spans took ${avg.toStringAsFixed(3)}ms avg');
    });

    test('setSize at 100K spans completes in < 10ms', () {
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

      expect(avg, lessThan(10.0),
          reason:
              'setSize at 100K spans took ${avg.toStringAsFixed(3)}ms avg');
    });

    test('setSize at 1M spans completes in < 50ms', () {
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

      expect(avg, lessThan(50.0),
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

  group('LayoutSolver visible range repeated calculations', () {
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

    test('1000 repeated identical lookups complete in < 5ms total', () {
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

      // Binary search is fast enough without caching for repeated calls
      expect(totalMs, lessThan(5.0),
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

      // Binary search is O(log N) — fast enough without caching
      expect(avgUs, lessThan(50),
          reason:
              'Per-frame visible range took ${avgUs.toStringAsFixed(1)}us avg');
    });
  });
}
