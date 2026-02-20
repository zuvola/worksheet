import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/formula_reference_adjuster.dart';

void main() {
  group('defaultFormulaReferenceAdjuster', () {
    group('relative references', () {
      test('adjusts row down', () {
        expect(defaultFormulaReferenceAdjuster('=A1', 1, 0), '=A2');
      });

      test('adjusts column right', () {
        expect(defaultFormulaReferenceAdjuster('=A1', 0, 1), '=B1');
      });

      test('adjusts both row and column', () {
        expect(defaultFormulaReferenceAdjuster('=A1', 1, 1), '=B2');
      });

      test('adjusts by larger deltas', () {
        expect(defaultFormulaReferenceAdjuster('=A1', 5, 3), '=D6');
      });
    });

    group('absolute column (\$A1)', () {
      test('column unchanged, row shifts', () {
        expect(defaultFormulaReferenceAdjuster('=\$A1', 1, 0), '=\$A2');
      });

      test('column unchanged when shifting right', () {
        expect(defaultFormulaReferenceAdjuster('=\$A1', 0, 1), '=\$A1');
      });

      test('column unchanged, row shifts with both deltas', () {
        expect(defaultFormulaReferenceAdjuster('=\$A1', 2, 3), '=\$A3');
      });
    });

    group('absolute row (A\$1)', () {
      test('row unchanged when shifting down', () {
        expect(defaultFormulaReferenceAdjuster('=A\$1', 1, 0), '=A\$1');
      });

      test('column shifts, row unchanged', () {
        expect(defaultFormulaReferenceAdjuster('=A\$1', 0, 1), '=B\$1');
      });

      test('column shifts, row unchanged with both deltas', () {
        expect(defaultFormulaReferenceAdjuster('=A\$1', 2, 3), '=D\$1');
      });
    });

    group('fully absolute (\$A\$1)', () {
      test('unchanged with row delta', () {
        expect(defaultFormulaReferenceAdjuster('=\$A\$1', 1, 0), '=\$A\$1');
      });

      test('unchanged with column delta', () {
        expect(defaultFormulaReferenceAdjuster('=\$A\$1', 0, 1), '=\$A\$1');
      });

      test('unchanged with both deltas', () {
        expect(defaultFormulaReferenceAdjuster('=\$A\$1', 5, 5), '=\$A\$1');
      });
    });

    group('range references', () {
      test('adjusts both endpoints', () {
        expect(
          defaultFormulaReferenceAdjuster('=SUM(A1:A10)', 1, 0),
          '=SUM(A2:A11)',
        );
      });

      test('adjusts range with column shift', () {
        expect(
          defaultFormulaReferenceAdjuster('=SUM(A1:B5)', 0, 1),
          '=SUM(B1:C5)',
        );
      });

      test('mixed absolute in range', () {
        expect(
          defaultFormulaReferenceAdjuster('=SUM(\$A1:\$A10)', 1, 0),
          '=SUM(\$A2:\$A11)',
        );
      });

      test('fully absolute range unchanged', () {
        expect(
          defaultFormulaReferenceAdjuster('=SUM(\$A\$1:\$B\$5)', 1, 1),
          '=SUM(\$A\$1:\$B\$5)',
        );
      });
    });

    group('sheet references', () {
      test('adjusts with sheet prefix', () {
        expect(
          defaultFormulaReferenceAdjuster('=Sheet1!A1', 1, 0),
          '=Sheet1!A2',
        );
      });

      test('adjusts with quoted sheet prefix', () {
        expect(
          defaultFormulaReferenceAdjuster("='My Sheet'!A1", 1, 0),
          "='My Sheet'!A2",
        );
      });

      test('sheet + absolute column', () {
        expect(
          defaultFormulaReferenceAdjuster('=Sheet1!\$A1', 1, 0),
          '=Sheet1!\$A2',
        );
      });

      test('sheet + range', () {
        expect(
          defaultFormulaReferenceAdjuster("='My Sheet'!A1:B5", 1, 0),
          "='My Sheet'!A2:B6",
        );
      });
    });

    group('complex formulas', () {
      test('multiple references adjusted', () {
        expect(
          defaultFormulaReferenceAdjuster('=A1+B2*C3', 1, 0),
          '=A2+B3*C4',
        );
      });

      test('mixed absolute and relative', () {
        expect(
          defaultFormulaReferenceAdjuster('=A1+\$B\$2', 1, 0),
          '=A2+\$B\$2',
        );
      });

      test('function with multiple args', () {
        expect(
          defaultFormulaReferenceAdjuster('=IF(A1>0,B1,C1)', 1, 0),
          '=IF(A2>0,B2,C2)',
        );
      });
    });

    group('out of bounds → #REF!', () {
      test('negative column produces #REF!', () {
        expect(
          defaultFormulaReferenceAdjuster('=A1', 0, -1),
          '=#REF!',
        );
      });

      test('negative row produces #REF!', () {
        expect(
          defaultFormulaReferenceAdjuster('=A1', -1, 0),
          '=#REF!',
        );
      });

      test('partial out of bounds in expression', () {
        // A1 col 0 + (-1) = -1 → #REF!, B1 col 1 + (-1) = 0 → A1
        expect(
          defaultFormulaReferenceAdjuster('=A1+B1', 0, -1),
          '=#REF!+A1',
        );
      });
    });

    group('multi-letter columns', () {
      test('AA1 right by 1', () {
        expect(defaultFormulaReferenceAdjuster('=AA1', 0, 1), '=AB1');
      });

      test('Z1 right by 1', () {
        expect(defaultFormulaReferenceAdjuster('=Z1', 0, 1), '=AA1');
      });
    });

    group('quoted strings preserved', () {
      test('reference inside quotes not adjusted', () {
        expect(
          defaultFormulaReferenceAdjuster('="Label A1"+A1', 1, 0),
          '="Label A1"+A2',
        );
      });

      test('only string, no refs', () {
        expect(
          defaultFormulaReferenceAdjuster('="Hello"', 1, 0),
          '="Hello"',
        );
      });

      test('ref before and after string', () {
        expect(
          defaultFormulaReferenceAdjuster('=A1&" - "&B1', 1, 0),
          '=A2&" - "&B2',
        );
      });
    });

    group('edge cases', () {
      test('zero delta unchanged', () {
        expect(defaultFormulaReferenceAdjuster('=A1+B2', 0, 0), '=A1+B2');
      });

      test('no references unchanged', () {
        expect(defaultFormulaReferenceAdjuster('=1+2*3', 1, 0), '=1+2*3');
      });

      test('non-formula string returned as-is', () {
        expect(defaultFormulaReferenceAdjuster('hello', 1, 0), 'hello');
      });

      test('empty string', () {
        expect(defaultFormulaReferenceAdjuster('', 1, 0), '');
      });

      test('just equals sign', () {
        expect(defaultFormulaReferenceAdjuster('=', 1, 0), '=');
      });
    });
  });
}
