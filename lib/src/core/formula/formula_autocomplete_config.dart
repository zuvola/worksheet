/// A function definition for formula autocomplete.
///
/// Used by [FormulaAutocompleteConfig] to populate the autocomplete dropdown.
class FormulaFunction {
  /// The function name in uppercase, e.g. "SUM".
  final String name;

  /// The full signature, e.g. "SUM(number1, [number2], ...)".
  final String signature;

  /// Optional description, e.g. "Adds all numbers in a range."
  final String? description;

  const FormulaFunction({
    required this.name,
    required this.signature,
    this.description,
  });
}

/// Default prefix matcher: case-insensitive prefix match on function name.
bool _defaultMatches(String token, FormulaFunction fn) =>
    fn.name.toUpperCase().startsWith(token.toUpperCase());

/// Configuration for formula function autocomplete.
///
/// Pass an instance to [Worksheet.formulaAutocompleteConfig] to enable
/// autocomplete. Pass `null` (default) to disable it.
class FormulaAutocompleteConfig {
  /// The list of available functions to suggest.
  final List<FormulaFunction> functions;

  /// Maximum visible items in the dropdown before scrolling.
  final int maxVisibleItems;

  /// Minimum characters typed before showing suggestions.
  final int minChars;

  /// Matching function. Receives the typed token and a candidate function.
  /// Returns `true` if the function should appear in the suggestions.
  ///
  /// Defaults to case-insensitive prefix match on the function name.
  final bool Function(String token, FormulaFunction fn) matches;

  const FormulaAutocompleteConfig({
    required this.functions,
    this.maxVisibleItems = 8,
    this.minChars = 1,
    this.matches = _defaultMatches,
  });
}
