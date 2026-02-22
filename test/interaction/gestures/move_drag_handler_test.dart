import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/interaction/gestures/move_drag_handler.dart';
import 'package:worksheet/src/interaction/hit_testing/hit_tester.dart';

void main() {
  group('MoveDragHandler', () {
    // Layout: headerWidth=50, headerHeight=30, rowHeight=24, colWidth=100
    late LayoutSolver layoutSolver;
    late WorksheetHitTester hitTester;
    late MoveDragHandler handler;
    late CellRange? completedSource;
    late CellCoordinate? completedDest;
    late CellRange? lastPreview;
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

      completedSource = null;
      completedDest = null;
      lastPreview = null;
      cancelCalled = false;

      handler = MoveDragHandler(
        hitTester: hitTester,
        onMovePreviewUpdate: (range) => lastPreview = range,
        onMoveComplete: (source, dest) {
          completedSource = source;
          completedDest = dest;
        },
        onMoveCancel: () => cancelCalled = true,
      );
    });

    test('isMoving is false initially', () {
      expect(handler.isMoving, isFalse);
    });

    group('border drag start', () {
      test('start sets isMoving to true', () {
        final hit = hitTester.hitTest(
          position: const Offset(200.0, 53.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(1, 1, 3, 3),
        );

        handler.start(hit, const CellRange(1, 1, 3, 3));
        expect(handler.isMoving, isTrue);
      });
    });

    group('long-press start', () {
      test('longPressStart sets isMoving to true', () {
        handler.longPressStart(
          const CellCoordinate(1, 1),
          const CellRange(1, 1, 1, 1),
        );
        expect(handler.isMoving, isTrue);
      });
    });

    group('update', () {
      test('update calls onMovePreviewUpdate with correct range', () {
        // Source is 2x2: (1,1)-(2,2)
        final hit = hitTester.hitTest(
          position: const Offset(200.0, 53.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(1, 1, 2, 2),
        );
        handler.start(hit, const CellRange(1, 1, 2, 2));

        // Drag to cell (5, 5): screen (600, 162)
        handler.update(const Offset(600.0, 162.0), Offset.zero, 1.0);

        expect(lastPreview, isNotNull);
        expect(lastPreview!.startRow, 5);
        expect(lastPreview!.startColumn, 5);
        expect(lastPreview!.endRow, 6);
        expect(lastPreview!.endColumn, 6);
      });

      test('update without start is a no-op', () {
        handler.update(const Offset(600.0, 162.0), Offset.zero, 1.0);
        expect(lastPreview, isNull);
      });

      test('update clamps destination to grid bounds', () {
        // Source is 2x2: (0,0)-(1,1)
        final hit = hitTester.hitTest(
          position: const Offset(100.0, 77.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(0, 0, 1, 1),
        );
        handler.start(hit, const CellRange(0, 0, 1, 1));

        // Drag to last cell in grid: row 99 center = 30 + 99*24 + 12 = 2418
        // col 25 center = 50 + 25*100 + 50 = 2600
        handler.update(const Offset(2600.0, 2418.0), Offset.zero, 1.0);

        expect(lastPreview, isNotNull);
        // Max row for 2-row block: 100-1-1 = 98
        // Max col for 2-col block: 26-1-1 = 24
        expect(lastPreview!.startRow, lessThanOrEqualTo(98));
        expect(lastPreview!.startColumn, lessThanOrEqualTo(24));
      });
    });

    group('grab offset', () {
      test('grab offset is applied when moving selection', () {
        // Select (2,2)-(4,4), grab at cell (3,3) — offset should be (1,1)
        final hit = hitTester.hitTest(
          position: const Offset(400.0, 114.0), // cell (3,3) center
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(2, 2, 4, 4),
        );
        handler.start(hit, const CellRange(2, 2, 4, 4));

        // Drag to cell (7,7): screen (800, 198)
        handler.update(const Offset(800.0, 198.0), Offset.zero, 1.0);

        expect(lastPreview, isNotNull);
        // Grabbed at (3,3) which is offset (1,1) from source start (2,2)
        // Cell under cursor is (7,7), so dest = (7-1, 7-1) = (6,6)
        // Preview: (6,6)-(8,8)
        expect(lastPreview!.startRow, 6);
        expect(lastPreview!.startColumn, 6);
      });

      test('long-press grab offset works correctly', () {
        handler.longPressStart(
          const CellCoordinate(1, 1), // Grab cell
          const CellRange(0, 0, 2, 2), // Selection
        );
        // Offset should be (1-0, 1-0) = (1, 1)

        // Drag to cell (5,5): screen (600, 162)
        handler.update(const Offset(600.0, 162.0), Offset.zero, 1.0);

        expect(lastPreview, isNotNull);
        // dest = (5-1, 5-1) = (4, 4), preview (4,4)-(6,6)
        expect(lastPreview!.startRow, 4);
        expect(lastPreview!.startColumn, 4);
      });
    });

    group('completion', () {
      test('end with destination calls onMoveComplete', () {
        final hit = hitTester.hitTest(
          position: const Offset(100.0, 77.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(0, 0, 1, 1),
        );
        handler.start(hit, const CellRange(0, 0, 1, 1));
        handler.update(const Offset(400.0, 162.0), Offset.zero, 1.0);
        handler.end();

        expect(completedSource, const CellRange(0, 0, 1, 1));
        expect(completedDest, isNotNull);
        expect(handler.isMoving, isFalse);
      });

      test('end without update calls onMoveCancel', () {
        final hit = hitTester.hitTest(
          position: const Offset(100.0, 77.0),
          scrollOffset: Offset.zero,
          zoom: 1.0,
          selectionRange: const CellRange(0, 0, 1, 1),
        );
        handler.start(hit, const CellRange(0, 0, 1, 1));
        handler.end();

        expect(cancelCalled, isTrue);
        expect(completedSource, isNull);
        expect(handler.isMoving, isFalse);
      });

      test('end when destination equals source origin calls onMoveCancel', () {
        // Move to same position (no-op move)
        handler.longPressStart(
          const CellCoordinate(0, 0),
          const CellRange(0, 0, 0, 0),
        );
        // Update to same cell
        handler.update(const Offset(60.0, 40.0), Offset.zero, 1.0);
        handler.end();

        expect(cancelCalled, isTrue);
        expect(completedSource, isNull);
      });

      test('cancel calls onMoveCancel', () {
        handler.longPressStart(
          const CellCoordinate(1, 1),
          const CellRange(0, 0, 2, 2),
        );
        handler.update(const Offset(600.0, 162.0), Offset.zero, 1.0);
        handler.cancel();

        expect(cancelCalled, isTrue);
        expect(completedSource, isNull);
        expect(handler.isMoving, isFalse);
      });
    });

    test('reset clears all state', () {
      handler.longPressStart(
        const CellCoordinate(1, 1),
        const CellRange(0, 0, 2, 2),
      );
      handler.update(const Offset(600.0, 162.0), Offset.zero, 1.0);
      handler.reset();

      expect(handler.isMoving, isFalse);

      // After reset, update should be a no-op
      lastPreview = null;
      handler.update(const Offset(200.0, 200.0), Offset.zero, 1.0);
      expect(lastPreview, isNull);
    });
  });
}
