// Demonstrates formula function autocomplete.
//
// Type `=` in any cell, then start typing a function name (e.g. `SU`).
// A dropdown appears with matching functions. Use arrow keys to navigate,
// Tab/Enter to accept, Escape to dismiss.
//
// Run with: flutter run -t example/autocomplete.dart
import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: AutocompleteDemo()));

/// ~20 sample spreadsheet functions for the autocomplete dropdown.
const _sampleFunctions = [
  FormulaFunction(
    name: 'ABS',
    signature: 'ABS(number)',
    description: 'Returns the absolute value of a number.',
  ),
  FormulaFunction(
    name: 'AVERAGE',
    signature: 'AVERAGE(number1, [number2], ...)',
    description: 'Returns the arithmetic mean of its arguments.',
  ),
  FormulaFunction(
    name: 'CEILING',
    signature: 'CEILING(number, significance)',
    description: 'Rounds a number up to the nearest multiple of significance.',
  ),
  FormulaFunction(
    name: 'CONCAT',
    signature: 'CONCAT(text1, [text2], ...)',
    description: 'Joins several text strings into one.',
  ),
  FormulaFunction(
    name: 'COUNT',
    signature: 'COUNT(value1, [value2], ...)',
    description: 'Counts the number of cells that contain numbers.',
  ),
  FormulaFunction(
    name: 'COUNTA',
    signature: 'COUNTA(value1, [value2], ...)',
    description: 'Counts the number of non-empty cells.',
  ),
  FormulaFunction(
    name: 'FLOOR',
    signature: 'FLOOR(number, significance)',
    description: 'Rounds a number down to the nearest multiple of significance.',
  ),
  FormulaFunction(
    name: 'IF',
    signature: 'IF(condition, value_if_true, value_if_false)',
    description: 'Returns one value if a condition is true, another if false.',
  ),
  FormulaFunction(
    name: 'INDEX',
    signature: 'INDEX(array, row_num, [col_num])',
    description: 'Returns a value at a given position in a range.',
  ),
  FormulaFunction(
    name: 'LEFT',
    signature: 'LEFT(text, [num_chars])',
    description: 'Returns the leftmost characters from a text string.',
  ),
  FormulaFunction(
    name: 'LEN',
    signature: 'LEN(text)',
    description: 'Returns the number of characters in a text string.',
  ),
  FormulaFunction(
    name: 'MAX',
    signature: 'MAX(number1, [number2], ...)',
    description: 'Returns the largest value in a set of values.',
  ),
  FormulaFunction(
    name: 'MIN',
    signature: 'MIN(number1, [number2], ...)',
    description: 'Returns the smallest value in a set of values.',
  ),
  FormulaFunction(
    name: 'ROUND',
    signature: 'ROUND(number, num_digits)',
    description: 'Rounds a number to a specified number of digits.',
  ),
  FormulaFunction(
    name: 'SQRT',
    signature: 'SQRT(number)',
    description: 'Returns the positive square root of a number.',
  ),
  FormulaFunction(
    name: 'SUM',
    signature: 'SUM(number1, [number2], ...)',
    description: 'Adds all the numbers in a range of cells.',
  ),
  FormulaFunction(
    name: 'SUMIF',
    signature: 'SUMIF(range, criteria, [sum_range])',
    description: 'Adds cells that meet a given condition.',
  ),
  FormulaFunction(
    name: 'SUMPRODUCT',
    signature: 'SUMPRODUCT(array1, [array2], ...)',
    description: 'Returns the sum of products of corresponding ranges.',
  ),
  FormulaFunction(
    name: 'TRIM',
    signature: 'TRIM(text)',
    description: 'Removes extra spaces from text.',
  ),
  FormulaFunction(
    name: 'VLOOKUP',
    signature: 'VLOOKUP(lookup_value, table_array, col_index, [range_lookup])',
    description: 'Looks for a value in the first column and returns a value in the same row.',
  ),
];

class AutocompleteDemo extends StatefulWidget {
  const AutocompleteDemo({super.key});

  @override
  State<AutocompleteDemo> createState() => _AutocompleteDemoState();
}

class _AutocompleteDemoState extends State<AutocompleteDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        (0, 0): 'Try typing formulas:'.cell,
        (1, 0): 'Type =SU in cell B2'.cell,
        (2, 0): 'Type =AV in cell B3'.cell,
        (3, 0): 'Type =IF in cell B4'.cell,
        (1, 2): Cell.number(10),
        (2, 2): Cell.number(20),
        (3, 2): Cell.number(30),
      },
    );
    _editController = EditController();
  }

  @override
  void dispose() {
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formula Autocomplete Demo'),
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          editController: _editController,
          rowCount: 100,
          columnCount: 10,
          formulaAutocompleteConfig: const FormulaAutocompleteConfig(
            functions: _sampleFunctions,
          ),
          formulaReferenceConfig: const FormulaReferenceConfig(),
        ),
      ),
    );
  }
}
