import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_tokenizer.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';

void main() {
  group('FormulaTokenizer', () {
    test('empty formula returns empty list', () {
      expect(FormulaTokenizer.tokenize(''), isEmpty);
    });

    test('=A1 returns one token at offset 1..3', () {
      final tokens = FormulaTokenizer.tokenize('=A1');
      expect(tokens, hasLength(1));
      expect(tokens[0].start, 1);
      expect(tokens[0].end, 3);
      expect(tokens[0].text, 'A1');
      expect(tokens[0].cell, const CellCoordinate(0, 0));
      expect(tokens[0].range, isNull);
    });

    test('=A1+B2 returns two tokens with different colors', () {
      final tokens = FormulaTokenizer.tokenize('=A1+B2');
      expect(tokens, hasLength(2));

      expect(tokens[0].text, 'A1');
      expect(tokens[0].cell, const CellCoordinate(0, 0));
      expect(tokens[0].start, 1);
      expect(tokens[0].end, 3);

      expect(tokens[1].text, 'B2');
      expect(tokens[1].cell, const CellCoordinate(1, 1));
      expect(tokens[1].start, 4);
      expect(tokens[1].end, 6);

      expect(tokens[0].color, isNot(equals(tokens[1].color)));
    });

    test('=A1:C5 returns one token with range', () {
      final tokens = FormulaTokenizer.tokenize('=A1:C5');
      expect(tokens, hasLength(1));
      expect(tokens[0].text, 'A1:C5');
      expect(tokens[0].cell, const CellCoordinate(0, 0));
      expect(tokens[0].range, const CellRange(0, 0, 4, 2));
    });

    test('=\$A\$1 returns token with absolute ref preserved', () {
      final tokens = FormulaTokenizer.tokenize('=\$A\$1');
      expect(tokens, hasLength(1));
      expect(tokens[0].text, '\$A\$1');
      expect(tokens[0].cell, const CellCoordinate(0, 0));
    });

    test('=Sheet1!A1 returns token with sheet prefix', () {
      final tokens = FormulaTokenizer.tokenize('=Sheet1!A1');
      expect(tokens, hasLength(1));
      expect(tokens[0].text, 'Sheet1!A1');
      expect(tokens[0].cell, const CellCoordinate(0, 0));
    });

    test('="text"+A1 skips quoted string and finds A1', () {
      final tokens = FormulaTokenizer.tokenize('="text"+A1');
      expect(tokens, hasLength(1));
      expect(tokens[0].text, 'A1');
      expect(tokens[0].start, 8);
    });

    test('palette cycles after 6 refs', () {
      final tokens = FormulaTokenizer.tokenize('=A1+B1+C1+D1+E1+F1+G1');
      expect(tokens, hasLength(7));
      // 7th token should cycle back to first color
      expect(tokens[6].color, equals(tokens[0].color));
    });

    test('formula without = still tokenizes', () {
      final tokens = FormulaTokenizer.tokenize('A1+B2');
      expect(tokens, hasLength(2));
      expect(tokens[0].text, 'A1');
      expect(tokens[1].text, 'B2');
    });

    test('=SUM(A1,B2,C3:D4) returns three tokens', () {
      final tokens = FormulaTokenizer.tokenize('=SUM(A1,B2,C3:D4)');
      expect(tokens, hasLength(3));
      expect(tokens[0].text, 'A1');
      expect(tokens[1].text, 'B2');
      expect(tokens[2].text, 'C3:D4');
      expect(tokens[2].range, const CellRange(2, 2, 3, 3));
    });

    test('quoted sheet name with space parses correctly', () {
      final tokens = FormulaTokenizer.tokenize("='My Sheet'!A1");
      expect(tokens, hasLength(1));
      expect(tokens[0].text, "'My Sheet'!A1");
      expect(tokens[0].cell, const CellCoordinate(0, 0));
    });

    test('token colors are assigned from defaultColors', () {
      final tokens = FormulaTokenizer.tokenize('=A1');
      expect(tokens[0].color, FormulaTokenizer.defaultColors[0]);
    });

    test('multiple range references get distinct colors', () {
      final tokens = FormulaTokenizer.tokenize('=A1:B2+C3:D4');
      expect(tokens, hasLength(2));
      expect(tokens[0].color, isNot(equals(tokens[1].color)));
    });
  });
}
