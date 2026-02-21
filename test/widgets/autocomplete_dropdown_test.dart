import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_autocomplete_config.dart';
import 'package:worksheet/src/widgets/autocomplete_dropdown.dart';

void main() {
  const functions = [
    FormulaFunction(name: 'SUM', signature: 'SUM(number1, [number2], ...)'),
    FormulaFunction(
      name: 'SUMIF',
      signature: 'SUMIF(range, criteria, [sum_range])',
    ),
    FormulaFunction(
      name: 'SUMPRODUCT',
      signature: 'SUMPRODUCT(array1, [array2], ...)',
    ),
  ];

  Widget buildDropdown({
    List<FormulaFunction> matches = functions,
    int selectedIndex = 0,
    String prefix = 'SU',
    void Function(FormulaFunction)? onSelect,
    int maxVisibleItems = 8,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AutocompleteDropdown(
          matches: matches,
          selectedIndex: selectedIndex,
          prefix: prefix,
          onSelect: onSelect ?? (_) {},
          maxVisibleItems: maxVisibleItems,
        ),
      ),
    );
  }

  /// Finds RichText widgets whose plain text contains [text].
  Finder findRichTextContaining(String text) {
    return find.byWidgetPredicate((widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(text);
      }
      return false;
    });
  }

  group('AutocompleteDropdown', () {
    testWidgets('renders correct number of items', (tester) async {
      await tester.pumpWidget(buildDropdown());

      // Each function name appears in a RichText (bold prefix)
      // and each signature appears in a Text.
      // We check the signatures since they are plain Text widgets:
      expect(
        find.text('SUM(number1, [number2], ...)'),
        findsOneWidget,
      );
      expect(
        find.text('SUMIF(range, criteria, [sum_range])'),
        findsOneWidget,
      );
      expect(
        find.text('SUMPRODUCT(array1, [array2], ...)'),
        findsOneWidget,
      );
    });

    testWidgets('renders function names as RichText', (tester) async {
      await tester.pumpWidget(buildDropdown());

      // Function names are rendered as RichText with bold prefix
      expect(findRichTextContaining('SUM'), findsWidgets);
      expect(findRichTextContaining('SUMIF'), findsWidgets);
      expect(findRichTextContaining('SUMPRODUCT'), findsWidgets);
    });

    testWidgets('selected item is highlighted', (tester) async {
      await tester.pumpWidget(buildDropdown(selectedIndex: 1));

      // Find containers with the selected background color
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).color ==
                  AutocompleteDropdown.selectedColor)
          .toList();
      expect(containers, hasLength(1));
    });

    testWidgets('tap calls onSelect', (tester) async {
      FormulaFunction? selected;
      await tester.pumpWidget(
        buildDropdown(onSelect: (fn) => selected = fn),
      );

      // Tap on the SUMIF signature text (which is a plain Text widget)
      await tester.tap(find.text('SUMIF(range, criteria, [sum_range])'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.name, 'SUMIF');
    });

    testWidgets('scrollable when exceeding maxVisibleItems', (tester) async {
      final manyFunctions = List.generate(
        20,
        (i) => FormulaFunction(
          name: 'FUNC$i',
          signature: 'FUNC$i()',
        ),
      );
      await tester.pumpWidget(
        buildDropdown(
          matches: manyFunctions,
          prefix: 'FUNC',
          maxVisibleItems: 5,
        ),
      );

      // The widget has a constrained height — a ListView is present
      expect(find.byType(ListView), findsOneWidget);
      // First item's signature is visible
      expect(find.text('FUNC0()'), findsOneWidget);
    });

    testWidgets('empty matches renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(buildDropdown(matches: const []));

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('bold prefix highlighting in function name', (tester) async {
      await tester.pumpWidget(buildDropdown(prefix: 'SU'));

      // Find the RichText for "SUM" and verify structure
      final richTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((rt) => rt.text.toPlainText() == 'SUM')
          .toList();
      expect(richTexts, isNotEmpty);

      // The first span should have bold "SU", second "M" normal
      final span = richTexts.first.text as TextSpan;
      expect(span.children, hasLength(2));
      final boldSpan = span.children![0] as TextSpan;
      final normalSpan = span.children![1] as TextSpan;
      expect(boldSpan.text, 'SU');
      expect(boldSpan.style?.fontWeight, FontWeight.bold);
      expect(normalSpan.text, 'M');
      expect(normalSpan.style?.fontWeight, FontWeight.normal);
    });
  });
}
