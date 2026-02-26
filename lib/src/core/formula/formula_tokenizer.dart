import 'dart:ui';

import 'package:a1/a1.dart';

import '../data/data.dart';
import '../models/models.dart';

/// A parsed cell reference token within a formula string.
class FormulaToken {
  /// Character offset of the start of the token in the formula string.
  final int start;

  /// Character offset of the end of the token (exclusive).
  final int end;

  /// The raw text of the reference (e.g. "A1", "\$B\$3:C5", "Sheet1!A1").
  final String text;

  /// The resolved coordinate (start of range for range references).
  final CellCoordinate cell;

  /// Non-null for range references (e.g. A1:C5).
  final CellRange? range;

  /// The display color assigned from the palette.
  final Color color;

  const FormulaToken({
    required this.start,
    required this.end,
    required this.text,
    required this.cell,
    this.range,
    required this.color,
  });

  @override
  String toString() => 'FormulaToken($text, $start..$end)';
}

/// Tokenizes formula strings into [FormulaToken] objects with character
/// offsets, resolved coordinates, and assigned colors.
class FormulaTokenizer {
  /// The default color palette for cell reference highlighting.
  static const List<Color> defaultColors = [
    Color(0xFF0070C0), // blue
    Color(0xFFFF0000), // red
    Color(0xFF7030A0), // purple
    Color(0xFF00B050), // green
    Color(0xFFFFC000), // amber
    Color(0xFF00B0F0), // light blue
  ];

  /// Tokenizes [formula] into a list of [FormulaToken]s.
  ///
  /// Uses [formulaRefPattern] to find cell references, skipping quoted
  /// string regions. Colors are assigned cyclically from [defaultColors].
  static List<FormulaToken> tokenize(String formula) {
    if (formula.isEmpty) return const [];

    // Build a list of quoted-string regions to skip.
    final quotedRegions = <(int, int)>[];
    for (int i = 0; i < formula.length; i++) {
      if (formula[i] == '"') {
        final end = formula.indexOf('"', i + 1);
        if (end != -1) {
          quotedRegions.add((i, end));
          i = end;
        }
      }
    }

    bool isInQuote(int start, int end) {
      for (final (qs, qe) in quotedRegions) {
        if (start >= qs && end <= qe) return true;
      }
      return false;
    }

    final tokens = <FormulaToken>[];
    int colorIndex = 0;

    for (final match in formulaRefPattern.allMatches(formula)) {
      if (isInQuote(match.start, match.end)) continue;

      final full = match.group(0)!;

      // Strip sheet prefix to get the cell part.
      String cellPart = full;
      final exclamationIndex = full.indexOf('!');
      if (exclamationIndex != -1) {
        cellPart = full.substring(exclamationIndex + 1).trimLeft();
      }

      // Parse cell coordinate(s).
      final rangeParts = cellPart.split(':');
      final startA1 = A1.tryParse(rangeParts[0]);
      if (startA1 == null) continue;

      final startCell = CellCoordinate(startA1.row, startA1.column);

      CellRange? range;
      if (rangeParts.length == 2) {
        final endA1 = A1.tryParse(rangeParts[1]);
        if (endA1 != null) {
          range = CellRange.fromCoordinates(
            startCell,
            CellCoordinate(endA1.row, endA1.column),
          );
        }
      }

      tokens.add(
        FormulaToken(
          start: match.start,
          end: match.end,
          text: full,
          cell: startCell,
          range: range,
          color: defaultColors[colorIndex % defaultColors.length],
        ),
      );

      colorIndex++;
    }

    return tokens;
  }
}
