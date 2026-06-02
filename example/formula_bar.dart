import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: FormulaBarExample()));

/// Demonstrates the [FormulaBar] widget placed above a [Worksheet].
///
/// Run from the example/ directory:
///   flutter run -t formula_bar.dart
class FormulaBarExample extends StatefulWidget {
  const FormulaBarExample({super.key});

  @override
  State<FormulaBarExample> createState() => _FormulaBarExampleState();
}

class _FormulaBarExampleState extends State<FormulaBarExample> {
  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;
  String _selectedCellLabel = '';
  String _selectedCellDisplay = '';

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 26,
      cells: _buildSampleData(),
    );
    _controller = WorksheetController();
    _editController = EditController();
    _controller.selectionController.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _controller.selectionController.removeListener(_onSelectionChanged);
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (_editController.isEditing) return;
    final anchor = _controller.selectionController.anchor;
    if (anchor == null) {
      setState(() {
        _selectedCellLabel = '';
        _selectedCellDisplay = '';
      });
      return;
    }
    // Convert to A1 notation (e.g. row=0, col=0 → A1).
    final colLetter = _columnLabel(anchor.column);
    final label = '$colLetter${anchor.row + 1}';
    final cell = _data.getCell(anchor);
    setState(() {
      _selectedCellLabel = label;
      _selectedCellDisplay = cell?.displayValue ?? '';
    });
  }

  static String _columnLabel(int col) {
    var result = '';
    var n = col;
    do {
      result = String.fromCharCode('A'.codeUnitAt(0) + n % 26) + result;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return result;
  }

  Map<(int, int), Cell> _buildSampleData() {
    final cells = <(int, int), Cell>{};
    final headers = [
      'Name',
      'Category',
      'Price',
      'Qty',
      'Total',
      'Status',
      'Notes',
    ];
    for (int col = 0; col < headers.length; col++) {
      cells[(0, col)] = headers[col].cell;
    }

    final names = ['Widget A', 'Widget B', 'Gadget X', 'Gadget Y', 'Part Z'];
    final categories = ['Hardware', 'Software', 'Service', 'Hardware', 'Other'];
    final statuses = ['Active', 'Pending', 'Shipped', 'Active', 'Cancelled'];

    for (int row = 1; row <= 20; row++) {
      final i = (row - 1) % 5;
      cells[(row, 0)] = names[i].cell;
      cells[(row, 1)] = categories[i].cell;
      cells[(row, 2)] = Cell.number(
        10.0 + row * 1.5,
        format: CellFormat.currency,
      );
      cells[(row, 3)] = (row * 3).cell;
      cells[(row, 4)] = Cell.number(
        (10.0 + row * 1.5) * (row * 3),
        format: CellFormat.currency,
      );
      cells[(row, 5)] = statuses[i].cell;
      cells[(row, 6)] = 'Note for row $row'.cell;
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formula Bar')),
      body: Column(
        children: [
          // -------------------------------------------------------
          // Formula bar row: cell label + text field
          // -------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Cell label (e.g. "A1")
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedCellLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Formula bar text field
                Expanded(
                  child: FormulaBar(
                    editController: _editController,
                    idleText: _selectedCellDisplay,
                  ),
                ),
              ],
            ),
          ),
          // -------------------------------------------------------
          // Worksheet
          // -------------------------------------------------------
          Expanded(
            child: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: _data,
                controller: _controller,
                editController: _editController,
                rowCount: _data.rowCount,
                columnCount: _data.columnCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
