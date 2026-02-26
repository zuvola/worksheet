import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_autocomplete_config.dart';
import 'package:worksheet/src/core/formula/formula_function_tokenizer.dart';
import 'package:worksheet/src/interaction/controllers/autocomplete_controller.dart';

/// Creates a [KeyDownEvent] for the given logical key.
KeyDownEvent _keyDown(LogicalKeyboardKey key) {
  return KeyDownEvent(
    logicalKey: key,
    physicalKey: PhysicalKeyboardKey.abort, // placeholder
    timeStamp: Duration.zero,
  );
}

/// Creates a [KeyUpEvent] for the given logical key.
KeyUpEvent _keyUp(LogicalKeyboardKey key) {
  return KeyUpEvent(
    logicalKey: key,
    physicalKey: PhysicalKeyboardKey.abort,
    timeStamp: Duration.zero,
  );
}

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

  group('handleKeyEvent', () {
    test('arrowDown calls selectNext', () {
      controller.onTextChanged('=SU', 3);
      expect(controller.selectedIndex, 0);

      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.arrowDown),
      );

      expect(result, KeyEventResult.handled);
      expect(controller.selectedIndex, 1);
    });

    test('arrowUp calls selectPrevious', () {
      controller.onTextChanged('=SU', 3);
      controller.selectNext(); // move to 1
      expect(controller.selectedIndex, 1);

      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.arrowUp),
      );

      expect(result, KeyEventResult.handled);
      expect(controller.selectedIndex, 0);
    });

    test('Tab accepts and invokes onAccept', () {
      controller.onTextChanged('=SU', 3);

      FormulaFunction? acceptedFn;
      AutocompleteToken? acceptedToken;

      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.tab),
        onAccept: (fn, token) {
          acceptedFn = fn;
          acceptedToken = token;
        },
      );

      expect(result, KeyEventResult.handled);
      expect(controller.isVisible, isFalse);
      expect(acceptedFn!.name, 'SUM');
      expect(acceptedToken!.text, 'SU');
    });

    test('Enter accepts and invokes onAccept', () {
      controller.onTextChanged('=SU', 3);

      FormulaFunction? acceptedFn;
      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.enter),
        onAccept: (fn, token) => acceptedFn = fn,
      );

      expect(result, KeyEventResult.handled);
      expect(acceptedFn!.name, 'SUM');
    });

    test('NumpadEnter accepts and invokes onAccept', () {
      controller.onTextChanged('=SU', 3);

      FormulaFunction? acceptedFn;
      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.numpadEnter),
        onAccept: (fn, token) => acceptedFn = fn,
      );

      expect(result, KeyEventResult.handled);
      expect(acceptedFn!.name, 'SUM');
    });

    test('Escape dismisses dropdown', () {
      controller.onTextChanged('=SU', 3);
      expect(controller.isVisible, isTrue);

      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.escape),
      );

      expect(result, KeyEventResult.handled);
      expect(controller.isVisible, isFalse);
    });

    test('returns ignored when not visible', () {
      expect(controller.isVisible, isFalse);

      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.arrowDown),
      );

      expect(result, KeyEventResult.ignored);
    });

    test('returns ignored for KeyUpEvent', () {
      controller.onTextChanged('=SU', 3);

      final result = controller.handleKeyEvent(
        _keyUp(LogicalKeyboardKey.arrowDown),
      );

      expect(result, KeyEventResult.ignored);
    });

    test('returns ignored for unrelated keys', () {
      controller.onTextChanged('=SU', 3);

      final result = controller.handleKeyEvent(
        _keyDown(LogicalKeyboardKey.keyA),
      );

      expect(result, KeyEventResult.ignored);
    });
  });

  group('applyAcceptedFunction', () {
    late TextEditingController textController;

    setUp(() {
      textController = TextEditingController();
    });

    tearDown(() {
      textController.dispose();
    });

    test('replaces token at start of formula', () {
      textController.text = '=SU';
      const token = AutocompleteToken(start: 1, end: 3, text: 'SU');
      const fn = FormulaFunction(name: 'SUM', signature: 'SUM(n1, [n2])');

      AutocompleteController.applyAcceptedFunction(textController, fn, token);

      expect(textController.text, '=SUM(');
      expect(textController.selection.baseOffset, 5);
      expect(textController.selection.extentOffset, 5);
    });

    test('preserves text after token', () {
      textController.text = '=SU+A1';
      const token = AutocompleteToken(start: 1, end: 3, text: 'SU');
      const fn = FormulaFunction(name: 'SUM', signature: 'SUM(n1, [n2])');

      AutocompleteController.applyAcceptedFunction(textController, fn, token);

      expect(textController.text, '=SUM(+A1');
      expect(textController.selection.baseOffset, 5);
    });

    test('works with mid-formula token', () {
      textController.text = '=IF(AV';
      const token = AutocompleteToken(start: 4, end: 6, text: 'AV');
      const fn = FormulaFunction(
        name: 'AVERAGE',
        signature: 'AVERAGE(n1, [n2])',
      );

      AutocompleteController.applyAcceptedFunction(textController, fn, token);

      expect(textController.text, '=IF(AVERAGE(');
      expect(textController.selection.baseOffset, 12);
    });

    test('cursor positioned after opening parenthesis', () {
      textController.text = '=AB';
      const token = AutocompleteToken(start: 1, end: 3, text: 'AB');
      const fn = FormulaFunction(name: 'ABS', signature: 'ABS(number)');

      AutocompleteController.applyAcceptedFunction(textController, fn, token);

      expect(textController.text, '=ABS(');
      expect(
        textController.selection,
        const TextSelection.collapsed(offset: 5),
      );
    });
  });
}
