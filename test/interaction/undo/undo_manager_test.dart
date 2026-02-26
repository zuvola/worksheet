import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  group('UndoManager', () {
    late UndoManager manager;

    UndoEntry makeEntry(String label) => UndoEntry(
      label: label,
      affectedRange: CellRange.single(const CellCoordinate(0, 0)),
      cellsBefore: const {},
      mergesBefore: const [],
      selectionBefore: (null, null),
      cellsAfter: const {},
      mergesAfter: const [],
      selectionAfter: (null, null),
    );

    setUp(() {
      manager = UndoManager();
    });

    test('starts empty', () {
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('push adds to undo stack', () {
      manager.push(makeEntry('A'));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, 1);
    });

    test('push clears redo stack', () {
      manager.push(makeEntry('A'));
      manager.undo();
      expect(manager.canRedo, isTrue);

      manager.push(makeEntry('B'));
      expect(manager.canRedo, isFalse);
      expect(manager.redoCount, 0);
    });

    test('undo returns entry and pushes to redo', () {
      manager.push(makeEntry('A'));
      manager.push(makeEntry('B'));

      final entry = manager.undo();
      expect(entry, isNotNull);
      expect(entry!.label, 'B');
      expect(manager.undoCount, 1);
      expect(manager.redoCount, 1);
    });

    test('undo returns null when empty', () {
      expect(manager.undo(), isNull);
    });

    test('redo returns entry and pushes back to undo', () {
      manager.push(makeEntry('A'));
      manager.undo();

      final entry = manager.redo();
      expect(entry, isNotNull);
      expect(entry!.label, 'A');
      expect(manager.undoCount, 1);
      expect(manager.redoCount, 0);
    });

    test('redo returns null when empty', () {
      expect(manager.redo(), isNull);
    });

    test('multiple undo/redo cycle', () {
      manager.push(makeEntry('A'));
      manager.push(makeEntry('B'));
      manager.push(makeEntry('C'));

      expect(manager.undo()!.label, 'C');
      expect(manager.undo()!.label, 'B');
      expect(manager.redo()!.label, 'B');
      expect(manager.redo()!.label, 'C');
      expect(manager.undoCount, 3);
      expect(manager.redoCount, 0);
    });

    test('maxDepth evicts oldest entry', () {
      final small = UndoManager(maxDepth: 3);
      small.push(makeEntry('A'));
      small.push(makeEntry('B'));
      small.push(makeEntry('C'));
      small.push(makeEntry('D'));

      expect(small.undoCount, 3);
      // Oldest 'A' was evicted, newest is 'D'
      expect(small.undo()!.label, 'D');
      expect(small.undo()!.label, 'C');
      expect(small.undo()!.label, 'B');
      expect(small.undo(), isNull);
    });

    test('clear empties both stacks', () {
      manager.push(makeEntry('A'));
      manager.push(makeEntry('B'));
      manager.undo();
      manager.clear();

      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isFalse);
      expect(manager.undoCount, 0);
      expect(manager.redoCount, 0);
    });

    test('notifies listeners on push', () {
      int count = 0;
      manager.addListener(() => count++);
      manager.push(makeEntry('A'));
      expect(count, 1);
    });

    test('notifies listeners on undo', () {
      manager.push(makeEntry('A'));
      int count = 0;
      manager.addListener(() => count++);
      manager.undo();
      expect(count, 1);
    });

    test('notifies listeners on redo', () {
      manager.push(makeEntry('A'));
      manager.undo();
      int count = 0;
      manager.addListener(() => count++);
      manager.redo();
      expect(count, 1);
    });

    test('notifies listeners on clear', () {
      manager.push(makeEntry('A'));
      int count = 0;
      manager.addListener(() => count++);
      manager.clear();
      expect(count, 1);
    });
  });
}
