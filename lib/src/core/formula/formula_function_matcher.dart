import 'formula_autocomplete_config.dart';

/// Matches a typed token against the function list from a config.
///
/// Returns matching functions sorted alphabetically by name.
class FormulaFunctionMatcher {
  /// Returns all functions from [config] that match [token],
  /// sorted alphabetically by name.
  static List<FormulaFunction> match(
    String token,
    FormulaAutocompleteConfig config,
  ) {
    if (token.isEmpty) return const [];
    final results =
        config.functions.where((fn) => config.matches(token, fn)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return results;
  }
}
