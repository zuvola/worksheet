/// A token extracted from a formula string for autocomplete matching.
class AutocompleteToken {
  /// Start offset in the formula string (inclusive).
  final int start;

  /// End offset in the formula string (exclusive, equals cursor position).
  final int end;

  /// The token text (letters only).
  final String text;

  const AutocompleteToken({
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteToken &&
          start == other.start &&
          end == other.end &&
          text == other.text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'AutocompleteToken($start..$end, "$text")';
}

/// Extracts the alphabetic function-name token at the cursor position.
///
/// The token starts after any of `= + - * / ^ & < > ! ( { , ;` or space,
/// contains only ASCII letters, and ends at the cursor. Returns `null` if:
/// - The formula doesn't start with `=`
/// - The cursor is inside a quoted string
/// - The token contains digits (likely a cell reference, not a function name)
/// - There are no letters before the cursor at a valid position
class FormulaFunctionTokenizer {
  /// Extracts the autocomplete token from [formula] at [cursorOffset].
  ///
  /// Returns `null` if no valid function name token exists at the cursor.
  static AutocompleteToken? extractToken(String formula, int cursorOffset) {
    if (formula.isEmpty || cursorOffset <= 0 || cursorOffset > formula.length) {
      return null;
    }
    if (!formula.startsWith('=')) return null;

    // Check if cursor is inside a quoted string.
    var inQuote = false;
    for (var i = 0; i < cursorOffset; i++) {
      if (formula[i] == '"') inQuote = !inQuote;
    }
    if (inQuote) return null;

    // Delimiters that start a new token.
    const delimiters = '=+-*/^&<>!({, ;';

    // Walk backward from cursor to find token start.
    var tokenStart = cursorOffset;
    while (tokenStart > 0) {
      final ch = formula[tokenStart - 1];
      if (delimiters.contains(ch) || ch == ' ') break;
      tokenStart--;
    }

    if (tokenStart == cursorOffset) return null;

    final tokenText = formula.substring(tokenStart, cursorOffset);

    // Token must be all ASCII letters (no digits, no $, no :).
    for (var i = 0; i < tokenText.length; i++) {
      final c = tokenText.codeUnitAt(i);
      if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122))) {
        return null;
      }
    }

    return AutocompleteToken(
      start: tokenStart,
      end: cursorOffset,
      text: tokenText,
    );
  }
}
