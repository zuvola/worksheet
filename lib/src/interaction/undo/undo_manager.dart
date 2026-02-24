import 'package:flutter/foundation.dart';

import 'undo_entry.dart';

/// Manages undo/redo stacks for worksheet operations.
///
/// Stores [UndoEntry] snapshots and provides stack-based undo/redo.
/// Notifies listeners when the stack state changes (for UI updates
/// like enabling/disabling undo/redo buttons).
class UndoManager extends ChangeNotifier {
  /// Maximum number of undo entries to retain.
  final int maxDepth;

  final List<UndoEntry> _undoStack = [];
  final List<UndoEntry> _redoStack = [];

  /// Creates an [UndoManager] with the given [maxDepth].
  ///
  /// Defaults to 100 entries. When the stack exceeds this depth,
  /// the oldest entry is evicted.
  UndoManager({this.maxDepth = 100});

  /// Whether there are entries that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are entries that can be redone.
  bool get canRedo => _redoStack.isNotEmpty;

  /// The number of entries in the undo stack.
  int get undoCount => _undoStack.length;

  /// The number of entries in the redo stack.
  int get redoCount => _redoStack.length;

  /// Pushes a new entry onto the undo stack.
  ///
  /// Clears the redo stack (new mutation invalidates the redo history).
  /// Evicts the oldest entry if the stack exceeds [maxDepth].
  void push(UndoEntry entry) {
    _redoStack.clear();
    _undoStack.add(entry);
    if (_undoStack.length > maxDepth) {
      _undoStack.removeAt(0);
    }
    notifyListeners();
  }

  /// Pops the most recent entry from the undo stack and pushes it
  /// onto the redo stack.
  ///
  /// Returns null if the undo stack is empty.
  UndoEntry? undo() {
    if (_undoStack.isEmpty) return null;
    final entry = _undoStack.removeLast();
    _redoStack.add(entry);
    notifyListeners();
    return entry;
  }

  /// Pops the most recent entry from the redo stack and pushes it
  /// back onto the undo stack.
  ///
  /// Returns null if the redo stack is empty.
  UndoEntry? redo() {
    if (_redoStack.isEmpty) return null;
    final entry = _redoStack.removeLast();
    _undoStack.add(entry);
    notifyListeners();
    return entry;
  }

  /// Clears both undo and redo stacks.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}
