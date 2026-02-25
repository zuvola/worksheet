import 'package:flutter/foundation.dart';

import '../../core/models/cell.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';

/// A single undoable/redoable operation.
///
/// Stores complete snapshots of cell state (values, styles, formats, rich text)
/// and merge regions before and after the operation, along with selection state.
@immutable
class UndoEntry {
  /// Human-readable label for this operation (e.g. "Edit cell", "Paste").
  final String label;

  /// The range of cells affected by this operation.
  final CellRange affectedRange;

  /// Cell state before the operation. Keys are coordinates within [affectedRange].
  final Map<CellCoordinate, Cell> cellsBefore;

  /// Merge regions within [affectedRange] before the operation.
  final List<CellRange> mergesBefore;

  /// Selection state (anchor, focus) before the operation.
  final (CellCoordinate? anchor, CellCoordinate? focus) selectionBefore;

  /// Cell state after the operation.
  final Map<CellCoordinate, Cell> cellsAfter;

  /// Merge regions within [affectedRange] after the operation.
  final List<CellRange> mergesAfter;

  /// Selection state (anchor, focus) after the operation.
  final (CellCoordinate? anchor, CellCoordinate? focus) selectionAfter;

  /// Row sizes before the operation, or null if no row sizes changed.
  final Map<int, double>? rowSizesBefore;

  /// Column sizes before the operation, or null if no column sizes changed.
  final Map<int, double>? columnSizesBefore;

  /// Row sizes after the operation, or null if no row sizes changed.
  final Map<int, double>? rowSizesAfter;

  /// Column sizes after the operation, or null if no column sizes changed.
  final Map<int, double>? columnSizesAfter;

  const UndoEntry({
    required this.label,
    required this.affectedRange,
    required this.cellsBefore,
    required this.mergesBefore,
    required this.selectionBefore,
    required this.cellsAfter,
    required this.mergesAfter,
    required this.selectionAfter,
    this.rowSizesBefore,
    this.columnSizesBefore,
    this.rowSizesAfter,
    this.columnSizesAfter,
  });

  @override
  String toString() => 'UndoEntry($label, $affectedRange)';
}
