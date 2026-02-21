import 'package:flutter/foundation.dart';

import '../../core/formula/formula_autocomplete_config.dart';
import '../../core/formula/formula_function_matcher.dart';
import '../../core/formula/formula_function_tokenizer.dart';

/// Controls the state of the formula autocomplete dropdown.
///
/// Listens for text and cursor changes, extracts the current function name
/// token, runs matching, and manages the selected item in the dropdown.
class AutocompleteController extends ChangeNotifier {
  final FormulaAutocompleteConfig _config;

  List<FormulaFunction> _matches = const [];
  int _selectedIndex = 0;
  bool _isVisible = false;
  AutocompleteToken? _currentToken;

  AutocompleteController({required FormulaAutocompleteConfig config})
      : _config = config;

  /// Whether the dropdown should be visible.
  bool get isVisible => _isVisible;

  /// The current list of matching functions.
  List<FormulaFunction> get matches => _matches;

  /// The currently selected index in [matches].
  int get selectedIndex => _selectedIndex;

  /// The token currently being matched, or `null` if no token.
  AutocompleteToken? get currentToken => _currentToken;

  /// The autocomplete config.
  FormulaAutocompleteConfig get config => _config;

  /// Called when the formula text or cursor position changes.
  ///
  /// Extracts the token at the cursor, runs matching, and updates visibility.
  void onTextChanged(String text, int cursorOffset) {
    final token = FormulaFunctionTokenizer.extractToken(text, cursorOffset);

    if (token == null || token.text.length < _config.minChars) {
      if (_isVisible) {
        _isVisible = false;
        _matches = const [];
        _currentToken = null;
        _selectedIndex = 0;
        notifyListeners();
      }
      return;
    }

    final newMatches = FormulaFunctionMatcher.match(token.text, _config);

    if (newMatches.isEmpty) {
      if (_isVisible) {
        _isVisible = false;
        _matches = const [];
        _currentToken = null;
        _selectedIndex = 0;
        notifyListeners();
      }
      return;
    }

    _isVisible = true;
    _matches = newMatches;
    _currentToken = token;
    _selectedIndex = 0;
    notifyListeners();
  }

  /// Moves selection to the next item.
  void selectNext() {
    if (!_isVisible || _matches.isEmpty) return;
    if (_selectedIndex < _matches.length - 1) {
      _selectedIndex++;
      notifyListeners();
    }
  }

  /// Moves selection to the previous item.
  void selectPrevious() {
    if (!_isVisible || _matches.isEmpty) return;
    if (_selectedIndex > 0) {
      _selectedIndex--;
      notifyListeners();
    }
  }

  /// Accepts the currently selected function.
  ///
  /// Returns the selected [FormulaFunction] and the [AutocompleteToken]
  /// that was being matched. Returns `null` if the dropdown is not visible.
  ({FormulaFunction function, AutocompleteToken token})? accept() {
    if (!_isVisible || _matches.isEmpty || _currentToken == null) return null;
    final fn = _matches[_selectedIndex];
    final token = _currentToken!;
    _isVisible = false;
    _matches = const [];
    _currentToken = null;
    _selectedIndex = 0;
    notifyListeners();
    return (function: fn, token: token);
  }

  /// Dismisses the dropdown without accepting.
  void dismiss() {
    if (!_isVisible) return;
    _isVisible = false;
    _matches = const [];
    _currentToken = null;
    _selectedIndex = 0;
    notifyListeners();
  }
}
