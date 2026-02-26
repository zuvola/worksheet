import 'package:a1/a1.dart';

import '../models/cell_coordinate.dart';
import '../models/cell_range.dart';
import 'formula_tokenizer.dart';

/// Inserts, replaces, and cycles cell references within formula text.
class FormulaReferenceInserter {
  /// Inserts a single cell reference at [cursorOffset] in [formula].
  ///
  /// If [cursorOffset] falls within an existing token, that token is replaced.
  /// Otherwise the reference is inserted at the cursor position.
  ///
  /// Returns the updated formula text and new cursor offset.
  static ({String text, int cursorOffset}) insertCellRef({
    required String formula,
    required int cursorOffset,
    required CellCoordinate cell,
    required List<FormulaToken> tokens,
    required String Function(CellCoordinate) cellToRef,
  }) {
    final ref = cellToRef(cell);
    return _insertRef(
      formula: formula,
      cursorOffset: cursorOffset,
      ref: ref,
      tokens: tokens,
    );
  }

  /// Inserts a range reference at [cursorOffset] in [formula].
  ///
  /// If [cursorOffset] falls within an existing token, that token is replaced.
  /// Otherwise the reference is inserted at the cursor position.
  static ({String text, int cursorOffset}) insertRangeRef({
    required String formula,
    required int cursorOffset,
    required CellCoordinate start,
    required CellCoordinate end,
    required List<FormulaToken> tokens,
    required String Function(CellRange) rangeToRef,
  }) {
    final range = CellRange.fromCoordinates(start, end);
    final ref = rangeToRef(range);
    return _insertRef(
      formula: formula,
      cursorOffset: cursorOffset,
      ref: ref,
      tokens: tokens,
    );
  }

  /// Cycles the reference at [cursorOffset] through absolute/relative modes.
  ///
  /// Cycle: A1 → $A$1 → A$1 → $A1 → A1
  /// For ranges, both parts are cycled together.
  ///
  /// Returns null if the cursor is not on a reference token.
  static ({String text, int cursorOffset})? cycleAbsoluteRelative({
    required String formula,
    required int cursorOffset,
    required List<FormulaToken> tokens,
  }) {
    final token = _tokenAt(tokens, cursorOffset);
    if (token == null) return null;

    // Strip sheet prefix if present.
    String cellPart = token.text;
    String sheetPrefix = '';
    final excl = token.text.indexOf('!');
    if (excl != -1) {
      sheetPrefix = token.text.substring(0, excl + 1);
      cellPart = token.text.substring(excl + 1).trimLeft();
    }

    final parts = cellPart.split(':');
    final cycled = <String>[];

    for (final part in parts) {
      final a1 = A1.tryParse(part);
      if (a1 == null) return null;

      final (newColAbs, newRowAbs) = _nextAbsoluteMode(
        a1.columnAbsolute,
        a1.rowAbsolute,
      );

      final newRef = A1
          .fromVector(
            a1.column,
            a1.row,
            columnAbsolute: newColAbs,
            rowAbsolute: newRowAbs,
          )
          .toString();
      cycled.add(newRef);
    }

    final newTokenText = '$sheetPrefix${cycled.join(':')}';
    final before = formula.substring(0, token.start);
    final after = formula.substring(token.end);
    final newFormula = '$before$newTokenText$after';
    final newCursorOffset = token.start + newTokenText.length;

    return (text: newFormula, cursorOffset: newCursorOffset);
  }

  // --- Private helpers ---

  static ({String text, int cursorOffset}) _insertRef({
    required String formula,
    required int cursorOffset,
    required String ref,
    required List<FormulaToken> tokens,
  }) {
    final existing = _tokenAt(tokens, cursorOffset);

    if (existing != null) {
      // Replace existing token.
      final before = formula.substring(0, existing.start);
      final after = formula.substring(existing.end);
      return (
        text: '$before$ref$after',
        cursorOffset: existing.start + ref.length,
      );
    }

    // Insert at cursor position.
    final before = formula.substring(0, cursorOffset);
    final after = formula.substring(cursorOffset);
    return (text: '$before$ref$after', cursorOffset: cursorOffset + ref.length);
  }

  /// Finds the token containing [cursorOffset], or null if none.
  static FormulaToken? _tokenAt(List<FormulaToken> tokens, int cursorOffset) {
    for (final token in tokens) {
      if (cursorOffset >= token.start && cursorOffset <= token.end) {
        return token;
      }
    }
    return null;
  }

  /// Cycles through the four absolute/relative modes.
  ///
  /// (false, false) → (true, true) → (false, true) → (true, false) → (false, false)
  static (bool colAbs, bool rowAbs) _nextAbsoluteMode(
    bool colAbs,
    bool rowAbs,
  ) {
    if (!colAbs && !rowAbs) return (true, true);
    if (colAbs && rowAbs) return (false, true);
    if (!colAbs && rowAbs) return (true, false);
    return (false, false); // colAbs && !rowAbs
  }
}
