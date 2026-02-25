import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

import '../../helpers/mock_worksheet_action_context.dart';

void main() {
  group('Undo/Redo integration', () {
    late SparseWorksheetData data;
    late SelectionController selection;
    late UndoManager undoManager;
    late MockWorksheetActionContext ctx;

    setUp(() {
      data = SparseWorksheetData(rowCount: 20, columnCount: 10);
      selection = SelectionController();
      undoManager = UndoManager();
      ctx = MockWorksheetActionContext(
        selectionController: selection,
        maxRow: 20,
        maxColumn: 10,
        worksheetData: data,
        clipboardHandler: ClipboardHandler(
          data: data,
          selectionController: selection,
          serializer: TsvClipboardSerializer(),
        ),
        undoManager: undoManager,
      );
    });

    tearDown(() {
      data.dispose();
      selection.dispose();
    });

    test('recordUndo captures before/after for cell edit', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Old'));
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Edit cell', CellRange.single(const CellCoordinate(0, 0)),
          () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('New'));
      });

      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('New'));
      expect(undoManager.canUndo, isTrue);
    });

    test('undo restores previous value', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Old'));
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Edit', CellRange.single(const CellCoordinate(0, 0)), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('New'));
      });

      ctx.performUndo();
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('Old'));
    });

    test('redo re-applies value', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Old'));
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Edit', CellRange.single(const CellCoordinate(0, 0)), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('New'));
      });

      ctx.performUndo();
      ctx.performRedo();
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('New'));
    });

    test('undo restores selection state', () {
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Edit', CellRange.single(const CellCoordinate(1, 1)), () {
        data.setCell(const CellCoordinate(1, 1), const CellValue.text('X'));
        selection.selectCell(const CellCoordinate(1, 1));
      });

      ctx.performUndo();
      expect(selection.anchor, const CellCoordinate(0, 0));
      expect(selection.focus, const CellCoordinate(0, 0));
    });

    test('redo restores after-selection', () {
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Edit', CellRange.single(const CellCoordinate(1, 1)), () {
        data.setCell(const CellCoordinate(1, 1), const CellValue.text('X'));
        selection.selectCell(const CellCoordinate(1, 1));
      });

      ctx.performUndo();
      ctx.performRedo();
      expect(selection.anchor, const CellCoordinate(1, 1));
    });

    test('new mutation clears redo stack', () {
      ctx.recordUndo('A', const CellRange(0, 0, 0, 0), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('A'));
      });

      ctx.performUndo();
      expect(undoManager.canRedo, isTrue);

      ctx.recordUndo('B', const CellRange(0, 0, 0, 0), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('B'));
      });

      expect(undoManager.canRedo, isFalse);
    });

    test('undo clear cells restores content', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Keep'));
      data.setCell(const CellCoordinate(0, 1), CellValue.number(42));
      selection.selectRange(const CellRange(0, 0, 0, 1));

      ctx.recordUndo('Clear', const CellRange(0, 0, 0, 1), () {
        data.clearRange(const CellRange(0, 0, 0, 1));
      });

      expect(data.getCell(const CellCoordinate(0, 0)), isNull);
      expect(data.getCell(const CellCoordinate(0, 1)), isNull);

      ctx.performUndo();
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('Keep'));
      expect(data.getCell(const CellCoordinate(0, 1)),
          CellValue.number(42));
    });

    test('undo merge restores original values', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('A'));
      data.setCell(const CellCoordinate(0, 1), const CellValue.text('B'));
      selection.selectRange(const CellRange(0, 0, 0, 1));

      ctx.recordUndo('Merge', const CellRange(0, 0, 0, 1), () {
        data.mergeCells(const CellRange(0, 0, 0, 1));
      });

      expect(data.mergedCells.getRegion(const CellCoordinate(0, 0)), isNotNull);

      ctx.performUndo();
      expect(data.mergedCells.getRegion(const CellCoordinate(0, 0)), isNull);
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('A'));
      expect(data.getCell(const CellCoordinate(0, 1)),
          const CellValue.text('B'));
    });

    test('undo unmerge re-merges', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('M'));
      data.mergeCells(const CellRange(0, 0, 1, 1));
      selection.selectRange(const CellRange(0, 0, 1, 1));

      ctx.recordUndo('Unmerge', const CellRange(0, 0, 1, 1), () {
        data.unmergeCellsInRange(const CellRange(0, 0, 1, 1));
      });

      expect(data.mergedCells.getRegion(const CellCoordinate(0, 0)), isNull);

      ctx.performUndo();
      final region =
          data.mergedCells.getRegion(const CellCoordinate(0, 0));
      expect(region, isNotNull);
      expect(region!.range, const CellRange(0, 0, 1, 1));
    });

    test('undo style change restores original style', () {
      const style = CellStyle(
          backgroundColor: Color(0xFFFF0000));
      data.setStyle(const CellCoordinate(0, 0), style);
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Style', CellRange.single(const CellCoordinate(0, 0)),
          () {
        data.setStyle(const CellCoordinate(0, 0),
            const CellStyle(backgroundColor: Color(0xFF00FF00)));
      });

      ctx.performUndo();
      expect(data.getStyle(const CellCoordinate(0, 0)), style);
    });

    test('undo rich text toggle restores original', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('hi'));
      data.setRichText(const CellCoordinate(0, 0), [
        const TextSpan(text: 'hi'),
      ]);
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Bold', CellRange.single(const CellCoordinate(0, 0)), () {
        data.setRichText(const CellCoordinate(0, 0), [
          const TextSpan(
            text: 'hi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ]);
      });

      ctx.performUndo();
      final rt = data.getRichText(const CellCoordinate(0, 0));
      expect(rt, isNotNull);
      expect(rt!.first.style, isNull);
    });

    test('multiple undo/redo sequence', () {
      // Action 1: set A
      ctx.recordUndo('Set A', const CellRange(0, 0, 0, 0), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('A'));
      });

      // Action 2: set B
      ctx.recordUndo('Set B', const CellRange(0, 0, 0, 0), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('B'));
      });

      // Action 3: set C
      ctx.recordUndo('Set C', const CellRange(0, 0, 0, 0), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('C'));
      });

      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('C'));

      ctx.performUndo(); // back to B
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('B'));

      ctx.performUndo(); // back to A
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('A'));

      ctx.performUndo(); // back to empty
      expect(data.getCell(const CellCoordinate(0, 0)), isNull);

      ctx.performRedo(); // forward to A
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('A'));

      ctx.performRedo(); // forward to B
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('B'));
    });

    test('recordUndo without undoManager just executes mutation', () {
      final ctxNoUndo = MockWorksheetActionContext(
        selectionController: selection,
        maxRow: 20,
        maxColumn: 10,
        worksheetData: data,
        clipboardHandler: ClipboardHandler(
          data: data,
          selectionController: selection,
          serializer: TsvClipboardSerializer(),
        ),
        undoManager: null,
      );

      ctxNoUndo.recordUndo('Test', const CellRange(0, 0, 0, 0), () {
        data.setCell(const CellCoordinate(0, 0), const CellValue.text('X'));
      });

      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('X'));
      // No undo stack to check
    });

    test('undo format change restores original format', () {
      data.setFormat(const CellCoordinate(0, 0), CellFormat.currency);
      selection.selectCell(const CellCoordinate(0, 0));

      ctx.recordUndo('Format', CellRange.single(const CellCoordinate(0, 0)),
          () {
        data.setFormat(const CellCoordinate(0, 0), CellFormat.percentage);
      });

      ctx.performUndo();
      expect(data.getFormat(const CellCoordinate(0, 0)), CellFormat.currency);
    });

    test('undo fill down restores original values', () {
      data.setCell(const CellCoordinate(0, 0), const CellValue.text('Src'));
      selection.selectRange(const CellRange(0, 0, 2, 0));

      ctx.recordUndo('Fill Down', const CellRange(0, 0, 2, 0), () {
        data.fillRange(
          const CellCoordinate(0, 0),
          const CellRange(1, 0, 2, 0),
        );
      });

      expect(data.getCell(const CellCoordinate(1, 0)),
          const CellValue.text('Src'));
      expect(data.getCell(const CellCoordinate(2, 0)),
          const CellValue.text('Src'));

      ctx.performUndo();
      expect(data.getCell(const CellCoordinate(1, 0)), isNull);
      expect(data.getCell(const CellCoordinate(2, 0)), isNull);
      // Source preserved
      expect(data.getCell(const CellCoordinate(0, 0)),
          const CellValue.text('Src'));
    });

    group('resize undo/redo', () {
      late LayoutSolver solver;
      late MockWorksheetActionContext ctxWithSolver;

      setUp(() {
        solver = LayoutSolver(
          rows: SpanList(count: 20, defaultSize: 25.0),
          columns: SpanList(count: 10, defaultSize: 100.0),
        );
        ctxWithSolver = MockWorksheetActionContext(
          selectionController: selection,
          maxRow: 20,
          maxColumn: 10,
          worksheetData: data,
          clipboardHandler: ClipboardHandler(
            data: data,
            selectionController: selection,
            serializer: TsvClipboardSerializer(),
          ),
          layoutSolver: solver,
          undoManager: undoManager,
        );
      });

      test('undo restores row size', () {
        solver.setRowHeight(3, 50.0);
        final sel = (selection.anchor, selection.focus);
        undoManager.push(UndoEntry(
          label: 'Resize row',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          rowSizesBefore: {3: 25.0},
          rowSizesAfter: {3: 50.0},
        ));

        expect(solver.getRowHeight(3), 50.0);

        ctxWithSolver.performUndo();
        expect(solver.getRowHeight(3), 25.0);
      });

      test('undo restores column size', () {
        solver.setColumnWidth(2, 200.0);
        final sel = (selection.anchor, selection.focus);
        undoManager.push(UndoEntry(
          label: 'Resize column',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          columnSizesBefore: {2: 100.0},
          columnSizesAfter: {2: 200.0},
        ));

        expect(solver.getColumnWidth(2), 200.0);

        ctxWithSolver.performUndo();
        expect(solver.getColumnWidth(2), 100.0);
      });

      test('redo re-applies resized dimensions', () {
        solver.setColumnWidth(5, 150.0);
        final sel = (selection.anchor, selection.focus);
        undoManager.push(UndoEntry(
          label: 'Resize column',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          columnSizesBefore: {5: 100.0},
          columnSizesAfter: {5: 150.0},
        ));

        ctxWithSolver.performUndo();
        expect(solver.getColumnWidth(5), 100.0);

        ctxWithSolver.performRedo();
        expect(solver.getColumnWidth(5), 150.0);
      });

      test('resize undo entry with no cell changes still works', () {
        // Record a cell edit first
        data.setCell(
            const CellCoordinate(0, 0), const CellValue.text('Keep'));
        ctxWithSolver.recordUndo(
            'Edit', CellRange.single(const CellCoordinate(0, 0)), () {
          data.setCell(
              const CellCoordinate(0, 0), const CellValue.text('Changed'));
        });

        // Then record a resize (no cell changes)
        solver.setRowHeight(1, 40.0);
        final sel = (selection.anchor, selection.focus);
        undoManager.push(UndoEntry(
          label: 'Resize row',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          rowSizesBefore: {1: 25.0},
          rowSizesAfter: {1: 40.0},
        ));

        // Undo resize
        ctxWithSolver.performUndo();
        expect(solver.getRowHeight(1), 25.0);
        // Cell still changed
        expect(data.getCell(const CellCoordinate(0, 0)),
            const CellValue.text('Changed'));

        // Undo cell edit
        ctxWithSolver.performUndo();
        expect(data.getCell(const CellCoordinate(0, 0)),
            const CellValue.text('Keep'));
      });

      test('existing cell-only undo entries unaffected by null size maps',
          () {
        // Use ctx with solver — null size maps should be harmless
        data.setCell(
            const CellCoordinate(0, 0), const CellValue.text('Before'));
        ctxWithSolver.recordUndo(
            'Edit', CellRange.single(const CellCoordinate(0, 0)), () {
          data.setCell(
              const CellCoordinate(0, 0), const CellValue.text('After'));
        });

        ctxWithSolver.performUndo();
        expect(data.getCell(const CellCoordinate(0, 0)),
            const CellValue.text('Before'));

        ctxWithSolver.performRedo();
        expect(data.getCell(const CellCoordinate(0, 0)),
            const CellValue.text('After'));
      });

      test('undo triggers invalidateAndRebuild for size changes', () {
        solver.setRowHeight(0, 60.0);
        final sel = (selection.anchor, selection.focus);
        undoManager.push(UndoEntry(
          label: 'Resize row',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          rowSizesBefore: {0: 25.0},
          rowSizesAfter: {0: 60.0},
        ));

        final beforeCount = ctxWithSolver.invalidateAndRebuildCount;
        ctxWithSolver.performUndo();
        expect(ctxWithSolver.invalidateAndRebuildCount, beforeCount + 1);
      });
    });
  });
}
