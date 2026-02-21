import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_autocomplete_config.dart';
import 'package:worksheet/src/core/formula/formula_function_matcher.dart';

void main() {
  const functions = [
    FormulaFunction(name: 'ABS', signature: 'ABS(number)'),
    FormulaFunction(name: 'AVERAGE', signature: 'AVERAGE(number1, [number2], ...)'),
    FormulaFunction(name: 'COUNT', signature: 'COUNT(value1, [value2], ...)'),
    FormulaFunction(name: 'IF', signature: 'IF(condition, true_val, false_val)'),
    FormulaFunction(name: 'SQRT', signature: 'SQRT(number)'),
    FormulaFunction(name: 'STDEV', signature: 'STDEV(number1, [number2], ...)'),
    FormulaFunction(name: 'SUM', signature: 'SUM(number1, [number2], ...)'),
    FormulaFunction(name: 'SUMIF', signature: 'SUMIF(range, criteria, [sum_range])'),
    FormulaFunction(name: 'SUMPRODUCT', signature: 'SUMPRODUCT(array1, [array2], ...)'),
  ];

  const config = FormulaAutocompleteConfig(functions: functions);

  group('FormulaFunctionMatcher.match', () {
    test('S matches SUM, SQRT, STDEV, SUMIF, SUMPRODUCT sorted', () {
      final results = FormulaFunctionMatcher.match('S', config);
      expect(results.map((f) => f.name).toList(), [
        'SQRT',
        'STDEV',
        'SUM',
        'SUMIF',
        'SUMPRODUCT',
      ]);
    });

    test('SUM matches SUM, SUMIF, SUMPRODUCT', () {
      final results = FormulaFunctionMatcher.match('SUM', config);
      expect(results.map((f) => f.name).toList(), [
        'SUM',
        'SUMIF',
        'SUMPRODUCT',
      ]);
    });

    test('case insensitive: sum matches SUM, SUMIF, SUMPRODUCT', () {
      final results = FormulaFunctionMatcher.match('sum', config);
      expect(results.map((f) => f.name).toList(), [
        'SUM',
        'SUMIF',
        'SUMPRODUCT',
      ]);
    });

    test('no matches returns empty list', () {
      final results = FormulaFunctionMatcher.match('XYZ', config);
      expect(results, isEmpty);
    });

    test('A matches ABS and AVERAGE', () {
      final results = FormulaFunctionMatcher.match('A', config);
      expect(results.map((f) => f.name).toList(), ['ABS', 'AVERAGE']);
    });

    test('empty token returns empty list', () {
      final results = FormulaFunctionMatcher.match('', config);
      expect(results, isEmpty);
    });

    test('exact match returns single result', () {
      final results = FormulaFunctionMatcher.match('COUNT', config);
      expect(results.map((f) => f.name).toList(), ['COUNT']);
    });

    test('results are alphabetically sorted', () {
      final results = FormulaFunctionMatcher.match('S', config);
      final names = results.map((f) => f.name).toList();
      final sorted = List<String>.from(names)..sort();
      expect(names, sorted);
    });

    test('custom matcher is used when provided', () {
      // Contains-match instead of prefix
      final customConfig = FormulaAutocompleteConfig(
        functions: functions,
        matches: (token, fn) => fn.name.contains(token.toUpperCase()),
      );
      final results = FormulaFunctionMatcher.match('PROD', customConfig);
      expect(results.map((f) => f.name).toList(), ['SUMPRODUCT']);
    });
  });
}
