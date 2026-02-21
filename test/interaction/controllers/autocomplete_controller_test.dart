import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_autocomplete_config.dart';
import 'package:worksheet/src/interaction/controllers/autocomplete_controller.dart';

void main() {
  const functions = [
    FormulaFunction(name: 'ABS', signature: 'ABS(number)'),
    FormulaFunction(name: 'AVERAGE', signature: 'AVERAGE(n1, [n2])'),
    FormulaFunction(name: 'SUM', signature: 'SUM(n1, [n2])'),
    FormulaFunction(name: 'SUMIF', signature: 'SUMIF(range, criteria)'),
    FormulaFunction(name: 'SUMPRODUCT', signature: 'SUMPRODUCT(a1, [a2])'),
  ];

  const config = FormulaAutocompleteConfig(functions: functions);

  late AutocompleteController controller;

  setUp(() {
    controller = AutocompleteController(config: config);
  });

  tearDown(() {
    controller.dispose();
  });

  group('initial state', () {
    test('not visible', () {
      expect(controller.isVisible, isFalse);
    });

    test('empty matches', () {
      expect(controller.matches, isEmpty);
    });

    test('selectedIndex is 0', () {
      expect(controller.selectedIndex, 0);
    });

    test('currentToken is null', () {
      expect(controller.currentToken, isNull);
    });
  });

  group('onTextChanged', () {
    test('with matching token shows dropdown', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.onTextChanged('=SU', 3);

      expect(controller.isVisible, isTrue);
      expect(controller.matches.map((f) => f.name).toList(), [
        'SUM',
        'SUMIF',
        'SUMPRODUCT',
      ]);
      expect(notified, isTrue);
    });

    test('with no match hides dropdown', () {
      controller.onTextChanged('=SU', 3);
      expect(controller.isVisible, isTrue);

      controller.onTextChanged('=XYZ', 4);
      expect(controller.isVisible, isFalse);
      expect(controller.matches, isEmpty);
    });

    test('non-formula text hides dropdown', () {
      controller.onTextChanged('hello', 5);
      expect(controller.isVisible, isFalse);
    });

    test('resets selectedIndex on new matches', () {
      controller.onTextChanged('=SU', 3);
      controller.selectNext();
      expect(controller.selectedIndex, 1);

      controller.onTextChanged('=SUM', 4);
      expect(controller.selectedIndex, 0);
    });

    test('token is preserved', () {
      controller.onTextChanged('=SU', 3);
      expect(controller.currentToken, isNotNull);
      expect(controller.currentToken!.text, 'SU');
    });
  });

  group('minChars', () {
    test('respects minChars = 2', () {
      final ctrl = AutocompleteController(
        config: const FormulaAutocompleteConfig(
          functions: functions,
          minChars: 2,
        ),
      );
      addTearDown(ctrl.dispose);

      ctrl.onTextChanged('=S', 2);
      expect(ctrl.isVisible, isFalse);

      ctrl.onTextChanged('=SU', 3);
      expect(ctrl.isVisible, isTrue);
    });
  });

  group('selectNext / selectPrevious', () {
    test('selectNext increments selectedIndex', () {
      controller.onTextChanged('=SU', 3);
      expect(controller.selectedIndex, 0);

      controller.selectNext();
      expect(controller.selectedIndex, 1);
    });

    test('selectNext clamps at last index', () {
      controller.onTextChanged('=SU', 3);
      // 3 matches: SUM, SUMIF, SUMPRODUCT

      controller.selectNext(); // 1
      controller.selectNext(); // 2
      controller.selectNext(); // still 2 (clamped)
      expect(controller.selectedIndex, 2);
    });

    test('selectPrevious decrements selectedIndex', () {
      controller.onTextChanged('=SU', 3);
      controller.selectNext(); // 1
      controller.selectPrevious();
      expect(controller.selectedIndex, 0);
    });

    test('selectPrevious clamps at 0', () {
      controller.onTextChanged('=SU', 3);
      controller.selectPrevious();
      expect(controller.selectedIndex, 0);
    });

    test('notifies listeners on navigation', () {
      controller.onTextChanged('=SU', 3);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.selectNext();
      expect(notified, isTrue);
    });
  });

  group('accept', () {
    test('returns selected function and token, then hides', () {
      controller.onTextChanged('=SU', 3);
      controller.selectNext(); // SUMIF

      final accepted = controller.accept();
      expect(accepted, isNotNull);
      expect(accepted!.function.name, 'SUMIF');
      expect(accepted.token.text, 'SU');
      expect(accepted.token.start, 1);
      expect(accepted.token.end, 3);
      expect(controller.isVisible, isFalse);
    });

    test('returns null when not visible', () {
      final accepted = controller.accept();
      expect(accepted, isNull);
    });

    test('returns first item when no navigation', () {
      controller.onTextChanged('=SU', 3);
      final accepted = controller.accept();
      expect(accepted!.function.name, 'SUM');
    });
  });

  group('dismiss', () {
    test('hides without accepting', () {
      controller.onTextChanged('=SU', 3);
      expect(controller.isVisible, isTrue);

      controller.dismiss();
      expect(controller.isVisible, isFalse);
      expect(controller.matches, isEmpty);
    });

    test('notifies listeners', () {
      controller.onTextChanged('=SU', 3);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.dismiss();
      expect(notified, isTrue);
    });
  });

  group('edge cases', () {
    test('empty function list never shows', () {
      final ctrl = AutocompleteController(
        config: const FormulaAutocompleteConfig(functions: []),
      );
      addTearDown(ctrl.dispose);

      ctrl.onTextChanged('=SU', 3);
      expect(ctrl.isVisible, isFalse);
    });

    test('single exact match still shows', () {
      controller.onTextChanged('=ABS', 4);
      expect(controller.isVisible, isTrue);
      expect(controller.matches.length, 1);
    });
  });
}
