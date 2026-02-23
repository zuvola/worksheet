import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: FrozenPanesExample()));

class FrozenPanesExample extends StatefulWidget {
  const FrozenPanesExample({super.key});

  @override
  State<FrozenPanesExample> createState() => _FrozenPanesExampleState();
}

class _FrozenPanesExampleState extends State<FrozenPanesExample> {
  late final SparseWorksheetData _data;
  late final EditController _editController;
  int _frozenRows = 1;
  int _frozenColumns = 1;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 200,
      columnCount: 26,
      cells: _buildSampleData(),
    );
    _editController = EditController();
  }

  Map<(int, int), Cell> _buildSampleData() {
    final cells = <(int, int), Cell>{};

    // Header row (row 0)
    final headers = [
      'ID', 'Name', 'Category', 'Price', 'Qty', 'Total',
      'Status', 'Date', 'Region', 'Notes',
    ];
    for (int col = 0; col < headers.length; col++) {
      cells[(0, col)] = headers[col].cell;
    }

    // Data rows
    final names = ['Widget A', 'Widget B', 'Gadget X', 'Gadget Y', 'Part Z'];
    final categories = ['Hardware', 'Software', 'Service', 'Hardware', 'Other'];
    final statuses = ['Active', 'Pending', 'Shipped', 'Active', 'Cancelled'];
    final regions = ['North', 'South', 'East', 'West', 'Central'];

    for (int row = 1; row <= 50; row++) {
      final i = (row - 1) % 5;
      cells[(row, 0)] = row.cell;
      cells[(row, 1)] = names[i].cell;
      cells[(row, 2)] = categories[i].cell;
      cells[(row, 3)] = Cell.number(
        10.0 + row * 1.5,
        format: CellFormat.currency,
      );
      cells[(row, 4)] = (row * 3).cell;
      cells[(row, 5)] = Cell.number(
        (10.0 + row * 1.5) * (row * 3),
        format: CellFormat.currency,
      );
      cells[(row, 6)] = statuses[i].cell;
      cells[(row, 7)] = Cell.date(
        DateTime(2026, 1, 1).add(Duration(days: row)),
        format: CellFormat.dateIso,
      );
      cells[(row, 8)] = regions[i].cell;
      cells[(row, 9)] = 'Note for row $row'.cell;
    }

    return cells;
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
        title: const Text('Frozen Panes'),
        actions: [
          // Frozen rows control
          const Text('Rows: '),
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Unfreeze row',
            onPressed: _frozenRows > 0
                ? () => setState(() => _frozenRows--)
                : null,
          ),
          Text('$_frozenRows', style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Freeze row',
            onPressed: _frozenRows < 5
                ? () => setState(() => _frozenRows++)
                : null,
          ),
          const SizedBox(width: 16),

          // Frozen columns control
          const Text('Cols: '),
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Unfreeze column',
            onPressed: _frozenColumns > 0
                ? () => setState(() => _frozenColumns--)
                : null,
          ),
          Text('$_frozenColumns', style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Freeze column',
            onPressed: _frozenColumns < 5
                ? () => setState(() => _frozenColumns++)
                : null,
          ),
          const SizedBox(width: 16),

          // Quick presets
          TextButton(
            onPressed: () => setState(() {
              _frozenRows = 0;
              _frozenColumns = 0;
            }),
            child: const Text('None'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _frozenRows = 1;
              _frozenColumns = 1;
            }),
            child: const Text('1x1'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _frozenRows = 1;
              _frozenColumns = 2;
            }),
            child: const Text('1x2'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          editController: _editController,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
          freezeConfig: FreezeConfig(
            frozenRows: _frozenRows,
            frozenColumns: _frozenColumns,
          ),
        ),
      ),
    );
  }
}
