import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_autocomplete_config.dart';
import 'package:worksheet/src/core/formula/formula_function_tokenizer.dart';

void main() {
  group('FormulaFunctionTokenizer.extractToken', () {
    test('returns null for empty string', () {
      expect(FormulaFunctionTokenizer.extractToken('', 0), isNull);
    });

    test('returns null for non-formula text', () {
      expect(FormulaFunctionTokenizer.extractToken('hello', 5), isNull);
    });

    test('returns null when cursor is at 0', () {
      expect(FormulaFunctionTokenizer.extractToken('=SUM', 0), isNull);
    });

    test('extracts token after = sign', () {
      final token = FormulaFunctionTokenizer.extractToken('=S', 2);
      expect(token, isNotNull);
      expect(token!.start, 1);
      expect(token.end, 2);
      expect(token.text, 'S');
    });

    test('extracts multi-char token after = sign', () {
      final token = FormulaFunctionTokenizer.extractToken('=SUM', 4);
      expect(token, isNotNull);
      expect(token!.start, 1);
      expect(token.end, 4);
      expect(token.text, 'SUM');
    });

    test('extracts token after operator', () {
      final token = FormulaFunctionTokenizer.extractToken('=SUM(A1)+AV', 11);
      expect(token, isNotNull);
      expect(token!.start, 9);
      expect(token.end, 11);
      expect(token.text, 'AV');
    });

    test('extracts token after comma', () {
      final token = FormulaFunctionTokenizer.extractToken('=SUM(A1,AV', 10);
      expect(token, isNotNull);
      expect(token!.start, 8);
      expect(token.end, 10);
      expect(token.text, 'AV');
    });

    test('returns null inside quotes', () {
      expect(FormulaFunctionTokenizer.extractToken('="SU', 4), isNull);
    });

    test('returns null inside double quotes mid-formula', () {
      expect(FormulaFunctionTokenizer.extractToken('=A1&"SU', 8), isNull);
    });

    test('returns null when token contains digits', () {
      expect(FormulaFunctionTokenizer.extractToken('=A1', 3), isNull);
    });

    test('extracts token after open paren', () {
      final token = FormulaFunctionTokenizer.extractToken('=IF(SU', 6);
      expect(token, isNotNull);
      expect(token!.start, 4);
      expect(token.end, 6);
      expect(token.text, 'SU');
    });

    test('returns null after paren with no letters', () {
      expect(FormulaFunctionTokenizer.extractToken('=SUM(', 5), isNull);
    });

    test('extracts token after space', () {
      final token = FormulaFunctionTokenizer.extractToken('=1 + SU', 7);
      expect(token, isNotNull);
      expect(token!.start, 5);
      expect(token.end, 7);
      expect(token.text, 'SU');
    });

    test('extracts lowercase token', () {
      final token = FormulaFunctionTokenizer.extractToken('=sum', 4);
      expect(token, isNotNull);
      expect(token!.text, 'sum');
    });

    test('returns null when cursor is at = position', () {
      expect(FormulaFunctionTokenizer.extractToken('=SUM', 1), isNull);
    });

    test('extracts token with cursor in middle of formula', () {
      final token = FormulaFunctionTokenizer.extractToken(
        '=SUM(A1)+AVERAGE(B1)',
        16,
      );
      expect(token, isNotNull);
      expect(token!.text, 'AVERAGE');
    });

    test('returns null when cursor is after a digit sequence', () {
      expect(FormulaFunctionTokenizer.extractToken('=123', 4), isNull);
    });

    test('extracts token after semicolon', () {
      final token = FormulaFunctionTokenizer.extractToken('=SUM(A1;AV', 10);
      expect(token, isNotNull);
      expect(token!.text, 'AV');
    });

    test('handles exclamation mark (sheet ref prefix)', () {
      final token = FormulaFunctionTokenizer.extractToken('=Sheet1!SU', 10);
      expect(token, isNotNull);
      expect(token!.text, 'SU');
    });

    test('returns null for cursor beyond string length', () {
      expect(FormulaFunctionTokenizer.extractToken('=S', 5), isNull);
    });

    test('extracts single letter token', () {
      final token = FormulaFunctionTokenizer.extractToken('=A', 2);
      expect(token, isNotNull);
      expect(token!.text, 'A');
    });

    test('returns null when closing quote not yet typed', () {
      // Inside an unclosed string literal
      expect(FormulaFunctionTokenizer.extractToken('="hello SU', 10), isNull);
    });

    test('extracts token after closed string', () {
      final token = FormulaFunctionTokenizer.extractToken('="hello"+SU', 11);
      expect(token, isNotNull);
      expect(token!.text, 'SU');
    });
  });

  group('FormulaFunction', () {
    test('creates with required fields', () {
      const fn = FormulaFunction(
        name: 'SUM',
        signature: 'SUM(number1, [number2], ...)',
      );
      expect(fn.name, 'SUM');
      expect(fn.signature, 'SUM(number1, [number2], ...)');
      expect(fn.description, isNull);
    });

    test('creates with description', () {
      const fn = FormulaFunction(
        name: 'SUM',
        signature: 'SUM(number1, [number2], ...)',
        description: 'Adds all numbers.',
      );
      expect(fn.description, 'Adds all numbers.');
    });
  });

  group('FormulaAutocompleteConfig', () {
    test('creates with defaults', () {
      const config = FormulaAutocompleteConfig(
        functions: [FormulaFunction(name: 'SUM', signature: 'SUM(n1, [n2])')],
      );
      expect(config.maxVisibleItems, 8);
      expect(config.minChars, 1);
    });

    test('creates with custom values', () {
      const config = FormulaAutocompleteConfig(
        functions: [],
        maxVisibleItems: 5,
        minChars: 2,
      );
      expect(config.maxVisibleItems, 5);
      expect(config.minChars, 2);
    });

    test('default matcher does prefix match', () {
      const config = FormulaAutocompleteConfig(functions: []);
      const fn = FormulaFunction(name: 'SUM', signature: 'SUM(n1)');
      expect(config.matches('SU', fn), isTrue);
      expect(config.matches('su', fn), isTrue);
      expect(config.matches('AV', fn), isFalse);
    });

    test('custom matcher works', () {
      final config = FormulaAutocompleteConfig(
        functions: const [],
        matches: (token, fn) => fn.name.contains(token.toUpperCase()),
      );
      const fn = FormulaFunction(name: 'SUMPRODUCT', signature: 'SUMPRODUCT()');
      expect(config.matches('PROD', fn), isTrue);
    });
  });

  group('AutocompleteToken', () {
    test('equality', () {
      const a = AutocompleteToken(start: 1, end: 3, text: 'SU');
      const b = AutocompleteToken(start: 1, end: 3, text: 'SU');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      const token = AutocompleteToken(start: 1, end: 3, text: 'SU');
      expect(token.toString(), contains('SU'));
    });
  });
}
