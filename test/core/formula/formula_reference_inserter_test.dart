import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_reference_inserter.dart';
import 'package:worksheet/src/core/formula/formula_tokenizer.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

void main() {
  String defaultCellToRef(CellCoordinate c) => c.toNotation();
  String defaultRangeToRef(CellRange r) =>
      '${r.topLeft.toNotation()}:${r.bottomRight.toNotation()}';

  group('FormulaReferenceInserter.insertCellRef', () {
    test('insert at end of = produces =A1', () {
      final formula = '=';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertCellRef(
        formula: formula,
        cursorOffset: 1,
        cell: const CellCoordinate(0, 0),
        tokens: tokens,
        cellToRef: defaultCellToRef,
      );
      expect(result.text, '=A1');
      expect(result.cursorOffset, 3);
    });

    test('insert after operator: =A1+| produces =A1+B2', () {
      final formula = '=A1+';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertCellRef(
        formula: formula,
        cursorOffset: 4,
        cell: const CellCoordinate(1, 1),
        tokens: tokens,
        cellToRef: defaultCellToRef,
      );
      expect(result.text, '=A1+B2');
      expect(result.cursorOffset, 6);
    });

    test('replace existing ref: cursor within A1 in =A1+B2 produces =C3+B2',
        () {
      final formula = '=A1+B2';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertCellRef(
        formula: formula,
        cursorOffset: 2, // within A1
        cell: const CellCoordinate(2, 2),
        tokens: tokens,
        cellToRef: defaultCellToRef,
      );
      expect(result.text, '=C3+B2');
      expect(result.cursorOffset, 3);
    });

    test('insert preserves surrounding text', () {
      final formula = '=SUM()+1';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertCellRef(
        formula: formula,
        cursorOffset: 5, // inside SUM()
        cell: const CellCoordinate(0, 0),
        tokens: tokens,
        cellToRef: defaultCellToRef,
      );
      expect(result.text, '=SUM(A1)+1');
      expect(result.cursorOffset, 7);
    });

    test('replace ref at cursor start boundary', () {
      final formula = '=A1+B2';
      final tokens = FormulaTokenizer.tokenize(formula);
      // cursor at token start (offset 1 = start of A1)
      final result = FormulaReferenceInserter.insertCellRef(
        formula: formula,
        cursorOffset: 1,
        cell: const CellCoordinate(9, 9),
        tokens: tokens,
        cellToRef: defaultCellToRef,
      );
      expect(result.text, '=J10+B2');
    });

    test('cursor position updated correctly after insertion', () {
      final formula = '=';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertCellRef(
        formula: formula,
        cursorOffset: 1,
        cell: const CellCoordinate(99, 25), // Z100
        tokens: tokens,
        cellToRef: defaultCellToRef,
      );
      expect(result.text, '=Z100');
      expect(result.cursorOffset, 5); // after "Z100"
    });
  });

  group('FormulaReferenceInserter.insertRangeRef', () {
    test('insert range at end of = produces =A1:C5', () {
      final formula = '=';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertRangeRef(
        formula: formula,
        cursorOffset: 1,
        start: const CellCoordinate(0, 0),
        end: const CellCoordinate(4, 2),
        tokens: tokens,
        rangeToRef: defaultRangeToRef,
      );
      expect(result.text, '=A1:C5');
      expect(result.cursorOffset, 6);
    });

    test('replace ref with range: cursor at A1 in =A1+B2 produces =A1:C5+B2',
        () {
      final formula = '=A1+B2';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.insertRangeRef(
        formula: formula,
        cursorOffset: 2, // within A1
        start: const CellCoordinate(0, 0),
        end: const CellCoordinate(4, 2),
        tokens: tokens,
        rangeToRef: defaultRangeToRef,
      );
      expect(result.text, '=A1:C5+B2');
      expect(result.cursorOffset, 6);
    });
  });

  group('FormulaReferenceInserter.cycleAbsoluteRelative', () {
    test('A1 -> \$A\$1', () {
      final formula = '=A1';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 2,
        tokens: tokens,
      );
      expect(result, isNotNull);
      expect(result!.text, '=\$A\$1');
    });

    test('\$A\$1 -> A\$1', () {
      final formula = '=\$A\$1';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 2,
        tokens: tokens,
      );
      expect(result, isNotNull);
      expect(result!.text, '=A\$1');
    });

    test('A\$1 -> \$A1', () {
      final formula = '=A\$1';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 2,
        tokens: tokens,
      );
      expect(result, isNotNull);
      expect(result!.text, '=\$A1');
    });

    test('\$A1 -> A1', () {
      final formula = '=\$A1';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 2,
        tokens: tokens,
      );
      expect(result, isNotNull);
      expect(result!.text, '=A1');
    });

    test('F4 on range: =A1:B2 -> \$A\$1:\$B\$2', () {
      final formula = '=A1:B2';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 2,
        tokens: tokens,
      );
      expect(result, isNotNull);
      expect(result!.text, '=\$A\$1:\$B\$2');
    });

    test('cursor not on ref returns null', () {
      final formula = '=A1+';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 4,
        tokens: tokens,
      );
      expect(result, isNull);
    });

    test('cursor position updated after cycling', () {
      final formula = '=A1+B2';
      final tokens = FormulaTokenizer.tokenize(formula);
      final result = FormulaReferenceInserter.cycleAbsoluteRelative(
        formula: formula,
        cursorOffset: 2,
        tokens: tokens,
      );
      expect(result, isNotNull);
      // =A1 (3 chars) -> =$A$1 (5 chars), cursor should be at end of new token
      expect(result!.cursorOffset, 5);
    });
  });
}
