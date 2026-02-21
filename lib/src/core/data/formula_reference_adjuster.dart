import 'package:a1/a1.dart';

/// Callback that adjusts cell references in a formula during fill operations.
///
/// Given a [formula] string (e.g. `=A1+B2`), a [rowDelta], and a [colDelta],
/// returns the formula with relative references shifted by the deltas.
/// Absolute references (marked with `$`) are left unchanged.
///
/// Example:
/// ```dart
/// final adjuster = defaultFormulaReferenceAdjuster;
/// adjuster('=A1+B2', 1, 0);  // '=A2+B3'
/// adjuster('=\$A1', 1, 0);   // '=\$A2' (column locked)
/// adjuster('=A\$1', 1, 0);   // '=A\$1' (row locked)
/// ```
typedef FormulaReferenceAdjuster = String Function(
  String formula,
  int rowDelta,
  int colDelta,
);

/// Regex for cell references, with optional sheet prefix.
///
/// Groups:
/// - 0: full match
/// - 1: sheet prefix (e.g. `Sheet1!` or `'My Sheet'!`)
/// - 2: cell part (e.g. `$A$1` or `A1:B5`)
final formulaRefPattern = RegExp(
  r"""(?:'(?:[^']|'')*'!\s*|[A-Za-z_]\w*!\s*)?"""
  r"""\$?[A-Za-z]{1,3}\$?\d+"""
  r"""(?::\$?[A-Za-z]{1,3}\$?\d+)?""",
);

/// Default implementation of [FormulaReferenceAdjuster] using the `a1` package.
///
/// Scans [formula] for A1-style cell references (including sheet-qualified and
/// range references), adjusts relative references by [rowDelta]/[colDelta],
/// and preserves absolute references (those marked with `$`).
///
/// References that would go out of bounds (negative row or column) are
/// replaced with `#REF!`. Quoted strings within the formula are preserved
/// without modification.
String defaultFormulaReferenceAdjuster(
  String formula,
  int rowDelta,
  int colDelta,
) {
  if (formula.isEmpty) return formula;

  // Build a list of quoted-string regions to skip
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

  final buffer = StringBuffer();
  int lastEnd = 0;

  for (final match in formulaRefPattern.allMatches(formula)) {
    if (isInQuote(match.start, match.end)) continue;

    buffer.write(formula.substring(lastEnd, match.start));

    final full = match.group(0)!;
    final adjusted = _adjustReference(full, rowDelta, colDelta);
    buffer.write(adjusted);

    lastEnd = match.end;
  }

  buffer.write(formula.substring(lastEnd));
  return buffer.toString();
}

/// Adjusts a single reference (possibly sheet-qualified, possibly a range).
String _adjustReference(String ref, int rowDelta, int colDelta) {
  // Split off sheet prefix if present
  String sheetPrefix = '';
  String cellPart = ref;

  final exclamationIndex = ref.indexOf('!');
  if (exclamationIndex != -1) {
    sheetPrefix = ref.substring(0, exclamationIndex + 1);
    cellPart = ref.substring(exclamationIndex + 1).trimLeft();
  }

  // Split on ':' for range references
  final parts = cellPart.split(':');
  final adjusted = <String>[];

  for (final part in parts) {
    final result = _adjustCell(part, rowDelta, colDelta);
    if (result == null) return '#REF!';
    adjusted.add(result);
  }

  return '$sheetPrefix${adjusted.join(':')}';
}

/// Adjusts a single cell reference (e.g. `$A1`, `B$5`, `AA3`).
/// Returns null if the result would be out of bounds.
String? _adjustCell(String cellText, int rowDelta, int colDelta) {
  final a1 = A1.tryParse(cellText);
  if (a1 == null) return cellText; // not a valid cell ref, return as-is

  final newCol = a1.columnAbsolute ? a1.column : a1.column + colDelta;
  final newRow = a1.rowAbsolute ? a1.row : a1.row + rowDelta;

  if (newCol < 0 || newRow < 0) return null;

  return A1.fromVector(
    newCol,
    newRow,
    columnAbsolute: a1.columnAbsolute,
    rowAbsolute: a1.rowAbsolute,
  ).toString();
}
