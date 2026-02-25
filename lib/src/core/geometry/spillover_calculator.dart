import '../data/data.dart';
import '../models/models.dart';
import 'layout_solver.dart';

/// The result of computing text spillover extent for a cell.
class SpilloverExtent {
  /// The leftmost column the text reaches (may be less than the source column
  /// for right-aligned or center-aligned text).
  final int startColumn;

  /// The rightmost column the text reaches.
  final int endColumn;

  /// The total pixel width across all spanned columns.
  final double totalWidth;

  /// True when a numeric/date/duration/boolean value overflows — display
  /// `######` instead of spilling.
  final bool showHashFill;

  const SpilloverExtent({
    required this.startColumn,
    required this.endColumn,
    required this.totalWidth,
    required this.showHashFill,
  });

  /// Whether the text actually spills beyond the source cell.
  bool get hasSpillover => !showHashFill && startColumn != endColumn;

  /// No-spill sentinel for the common fast path.
  const SpilloverExtent.noSpill({
    required int column,
    required double cellWidth,
  })  : startColumn = column,
        endColumn = column,
        totalWidth = cellWidth,
        showHashFill = false;
}

/// Pure utility for computing how far a cell's text spills into adjacent
/// empty columns.
///
/// Left-aligned text spills right, right-aligned spills left,
/// center-aligned spills both directions. Numeric/date/duration/boolean
/// values that overflow display `######` instead of spilling.
class SpilloverCalculator {
  SpilloverCalculator._();

  /// Computes the spillover extent for a cell's text.
  static SpilloverExtent compute({
    required int row,
    required int column,
    required double textWidth,
    required double cellWidth,
    required double cellPadding,
    required CellTextAlignment alignment,
    required CellValueType valueType,
    required bool wrapText,
    required WorksheetData data,
    required LayoutSolver layoutSolver,
    MergedCellRegistry? mergedCells,
    required int maxColumn,
  }) {
    // Wrap-text cells never spill.
    if (wrapText) {
      return SpilloverExtent.noSpill(column: column, cellWidth: cellWidth);
    }

    final availableWidth = cellWidth - 2 * cellPadding;
    if (textWidth <= availableWidth) {
      return SpilloverExtent.noSpill(column: column, cellWidth: cellWidth);
    }

    // Numeric/date/duration/boolean overflow → hash fill (######).
    if (_isHashFillType(valueType)) {
      return SpilloverExtent(
        startColumn: column,
        endColumn: column,
        totalWidth: cellWidth,
        showHashFill: true,
      );
    }

    // Determine the source cell's column span (for merged cells the source
    // occupies multiple columns).
    final region = mergedCells?.getRegion(CellCoordinate(row, column));
    final sourceStartCol = region?.range.startColumn ?? column;
    final sourceEndCol = region?.range.endColumn ?? column;

    // Compute excess width the text needs beyond the cell.
    final excessWidth = textWidth - availableWidth;

    var startCol = sourceStartCol;
    var endCol = sourceEndCol;
    var totalWidth = cellWidth;

    switch (alignment) {
      case CellTextAlignment.left:
        // Spill right
        var remaining = excessWidth;
        var nextCol = sourceEndCol + 1;
        while (remaining > 0 && nextCol <= maxColumn) {
          if (!_canSpillInto(row, nextCol, data, mergedCells)) break;
          final w = layoutSolver.getColumnWidth(nextCol);
          totalWidth += w;
          remaining -= w;
          endCol = nextCol;
          nextCol++;
        }
        break;

      case CellTextAlignment.right:
        // Spill left
        var remaining = excessWidth;
        var nextCol = sourceStartCol - 1;
        while (remaining > 0 && nextCol >= 0) {
          if (!_canSpillInto(row, nextCol, data, mergedCells)) break;
          final w = layoutSolver.getColumnWidth(nextCol);
          totalWidth += w;
          remaining -= w;
          startCol = nextCol;
          nextCol--;
        }
        break;

      case CellTextAlignment.center:
        // Spill both directions, alternating
        final halfExcess = excessWidth / 2;
        var remainingLeft = halfExcess;
        var remainingRight = halfExcess;
        var leftCol = sourceStartCol - 1;
        var rightCol = sourceEndCol + 1;

        while (remainingLeft > 0 || remainingRight > 0) {
          var progressed = false;

          // Try right
          if (remainingRight > 0 && rightCol <= maxColumn) {
            if (_canSpillInto(row, rightCol, data, mergedCells)) {
              final w = layoutSolver.getColumnWidth(rightCol);
              totalWidth += w;
              remainingRight -= w;
              endCol = rightCol;
              rightCol++;
              progressed = true;
            } else {
              remainingRight = 0;
            }
          }

          // Try left
          if (remainingLeft > 0 && leftCol >= 0) {
            if (_canSpillInto(row, leftCol, data, mergedCells)) {
              final w = layoutSolver.getColumnWidth(leftCol);
              totalWidth += w;
              remainingLeft -= w;
              startCol = leftCol;
              leftCol--;
              progressed = true;
            } else {
              remainingLeft = 0;
            }
          }

          if (!progressed) break;
        }
        break;
    }

    // If we couldn't expand at all, no spillover.
    if (startCol == sourceStartCol && endCol == sourceEndCol) {
      return SpilloverExtent.noSpill(column: column, cellWidth: cellWidth);
    }

    return SpilloverExtent(
      startColumn: startCol,
      endColumn: endCol,
      totalWidth: totalWidth,
      showHashFill: false,
    );
  }

  /// Whether a column is available for spillover (empty and not merged).
  static bool _canSpillInto(
    int row,
    int col,
    WorksheetData data,
    MergedCellRegistry? mergedCells,
  ) {
    if (data.hasValue(CellCoordinate(row, col))) return false;
    if (mergedCells != null) {
      final region = mergedCells.getRegion(CellCoordinate(row, col));
      if (region != null) return false;
    }
    return true;
  }

  /// Returns true for value types that show `######` on overflow.
  static bool _isHashFillType(CellValueType type) {
    switch (type) {
      case CellValueType.number:
      case CellValueType.date:
      case CellValueType.duration:
      case CellValueType.boolean:
        return true;
      case CellValueType.text:
      case CellValueType.formula:
      case CellValueType.error:
        return false;
    }
  }
}
