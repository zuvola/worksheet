import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/interaction/gestures/fill_drag_handler.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_tester.dart';

void main() {
  group('FillDragHandler', () {
    // Layout: headerWidth=50, headerHeight=30, rowHeight=24, colWidth=100
    // Cell (r,c) screen position: (50 + c*100 + offset, 30 + r*24 + offset)
    late LayoutSolver layoutSolver;
    late WorksheetHitTester hitTester;
    late FillDragHandler handler;
    late List<CellRange> previewRanges;
    late CellRange? completedSource;
    late CellCoordinate? completedDest;
    late bool cancelCalled;

    setUp(() {
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
      hitTester = WorksheetHitTester(
        layoutSolver: layoutSolver,
        headerWidth: 50.0,
        headerHeight: 30.0,
      );

      previewRanges = [];
      completedSource = null;
      completedDest = null;
      cancelCalled = false;

      handler = FillDragHandler(
        hitTester: hitTester,
        onFillPreviewUpdate: (range) => previewRanges.add(range),
        onFillComplete: (source, dest) {
          completedSource = source;
          completedDest = dest;
        },
        onFillCancel: () => cancelCalled = true,
      );
    });

    test('isFilling is false initially', () {
      expect(handler.isFilling, isFalse);
    });

    test('start sets isFilling to true', () {
      handler.start(const CellRange(0, 0, 2, 2), const Offset(349, 101));
      expect(handler.isFilling, isTrue);
    });

    group('axis constraint', () {
      void startFill() {
        handler.start(const CellRange(0, 0, 2, 2), const Offset(349, 101));
      }

      test('drag down locks to vertical axis', () {
        startFill();

        // Drag to row 4, inside source columns: screen (200, 138)
        handler.update(const Offset(200.0, 138.0), Offset.zero, 1.0);

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        expect(preview.startRow, 0);
        expect(preview.endRow, 4);
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 2);
      });

      test('drag right locks to horizontal axis', () {
        startFill();

        // Drag to col 4, inside source rows: screen (500, 60)
        handler.update(const Offset(500.0, 60.0), Offset.zero, 1.0);

        expect(previewRanges, hasLength(1));
        final preview = previewRanges.last;
        expect(preview.startRow, 0);
        expect(preview.endRow, 2);
        expect(preview.startColumn, 0);
        expect(preview.endColumn, 4);
      });

      test('diagonal drag locks to axis with greater pixel displacement', () {
        startFill();

        // More vertical (dy=80) than horizontal (dx=20)
        handler.update(const Offset(369.0, 181.0), Offset.zero, 1.0);

        expect(previewRanges, hasLength(1));
        // Vertical wins: columns stay as source
        expect(previewRanges.last.startColumn, 0);
        expect(previewRanges.last.endColumn, 2);
        expect(previewRanges.last.endRow, greaterThan(2));
      });

      test('diagonal drag locks horizontal when dx > dy', () {
        startFill();

        // More horizontal (dx=200) than vertical (dy=30)
        handler.update(const Offset(549.0, 131.0), Offset.zero, 1.0);

        expect(previewRanges, hasLength(1));
        // Horizontal wins: rows stay as source
        expect(previewRanges.last.startRow, 0);
        expect(previewRanges.last.endRow, 2);
        expect(previewRanges.last.endColumn, greaterThan(2));
      });

      test('axis lock persists across subsequent updates', () {
        startFill();

        // First update: lock vertical
        handler.update(const Offset(200.0, 138.0), Offset.zero, 1.0);
        expect(previewRanges.last.endColumn, 2);

        // Second update: drag right — still vertical
        handler.update(const Offset(600.0, 160.0), Offset.zero, 1.0);
        expect(previewRanges, hasLength(2));
        expect(previewRanges.last.startColumn, 0);
        expect(previewRanges.last.endColumn, 2);
      });

      test('cursor inside source range with no lock triggers no preview', () {
        startFill();

        // Cell (1,1) inside source (0,0)-(2,2): screen (200, 66)
        handler.update(const Offset(200.0, 66.0), Offset.zero, 1.0);
        expect(previewRanges, isEmpty);
      });

      test(
        'single-cell source allows free expansion without axis constraint',
        () {
          final singleHandler = FillDragHandler(
            hitTester: hitTester,
            onFillPreviewUpdate: (range) => previewRanges.add(range),
            onFillComplete: (source, dest) {},
            onFillCancel: () {},
          );

          singleHandler.start(
            const CellRange(2, 2, 2, 2),
            const Offset(349.0, 101.0),
          );

          // Drag diagonally to (5, 4): screen (500, 162)
          singleHandler.update(const Offset(500.0, 162.0), Offset.zero, 1.0);

          expect(previewRanges, hasLength(1));
          final preview = previewRanges.last;
          expect(preview.startRow, 2);
          expect(preview.startColumn, 2);
          expect(preview.endRow, 5);
          expect(preview.endColumn, 4);
        },
      );
    });

    group('completion', () {
      test('end with destination calls onFillComplete', () {
        handler.start(const CellRange(0, 0, 2, 2), const Offset(349, 101));
        handler.update(const Offset(200.0, 138.0), Offset.zero, 1.0);
        handler.end();

        expect(completedSource, const CellRange(0, 0, 2, 2));
        expect(completedDest, isNotNull);
        expect(completedDest!.column, 2); // Constrained to source col
        expect(handler.isFilling, isFalse);
      });

      test('end without update calls onFillCancel', () {
        handler.start(const CellRange(0, 0, 2, 2), const Offset(349, 101));
        handler.end();

        expect(cancelCalled, isTrue);
        expect(completedSource, isNull);
        expect(handler.isFilling, isFalse);
      });

      test('cancel calls onFillCancel', () {
        handler.start(const CellRange(0, 0, 2, 2), const Offset(349, 101));
        handler.update(const Offset(200.0, 138.0), Offset.zero, 1.0);
        handler.cancel();

        expect(cancelCalled, isTrue);
        expect(completedSource, isNull);
        expect(handler.isFilling, isFalse);
      });
    });

    test('reset clears all state', () {
      handler.start(const CellRange(0, 0, 2, 2), const Offset(349, 101));
      handler.update(const Offset(200.0, 138.0), Offset.zero, 1.0);
      handler.reset();

      expect(handler.isFilling, isFalse);

      // After reset, update should be a no-op (no source range)
      previewRanges.clear();
      handler.update(const Offset(200.0, 200.0), Offset.zero, 1.0);
      expect(previewRanges, isEmpty);
    });
  });
}
