import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: UndoRedoExample()));

class UndoRedoExample extends StatefulWidget {
  const UndoRedoExample({super.key});

  @override
  State<UndoRedoExample> createState() => _UndoRedoExampleState();
}

class _UndoRedoExampleState extends State<UndoRedoExample> {
  late final SparseWorksheetData _data;
  late final EditController _editController;
  late final UndoManager _undoManager;
  late final WorksheetController _controller;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        (0, 0): 'Name'.cell,
        (0, 1): 'Amount'.cell,
        (0, 2): 'Status'.cell,
        (1, 0): 'Apples'.cell,
        (1, 1): Cell.number(42, format: CellFormat.integer),
        (1, 2): 'Active'.cell,
        (2, 0): 'Bananas'.cell,
        (2, 1): Cell.number(18, format: CellFormat.integer),
        (2, 2): 'Pending'.cell,
        (3, 0): 'Cherries'.cell,
        (3, 1): Cell.number(95, format: CellFormat.integer),
        (3, 2): 'Active'.cell,
      },
    );
    _editController = EditController();
    _undoManager = UndoManager(maxDepth: 50);
    _controller = WorksheetController(undoManager: _undoManager);

    // Rebuild toolbar when undo/redo or selection state changes
    _undoManager.addListener(_onStateChanged);
    _controller.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _undoManager.removeListener(_onStateChanged);
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Undo / Redo'),
        actions: [
          // Undo and redo use convenience methods — these are shorthand for
          // _controller.invokeAction(const UndoIntent()) and RedoIntent().
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: _undoManager.canUndo
                ? () => _controller.undo()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: _undoManager.canRedo
                ? () => _controller.redo()
                : null,
          ),

          const VerticalDivider(width: 16),

          // Clear cells uses invokeAction/isActionEnabled — the general
          // pattern for wiring any worksheet action to external UI.
          // This works for any Intent: ClearCellsIntent, MergeCellsIntent,
          // ToggleBoldIntent, FillDownIntent, etc.
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear selected cells',
            onPressed: _controller.isActionEnabled(const ClearCellsIntent())
                ? () => _controller.invokeAction(const ClearCellsIntent())
                : null,
          ),

          const SizedBox(width: 8),

          // Stack depth indicator
          Center(
            child: Text(
              'Undo: ${_undoManager.undoCount}  Redo: ${_undoManager.redoCount}',
              style: const TextStyle(fontSize: 13),
            ),
          ),

          const SizedBox(width: 8),

          // Clear history button
          TextButton(
            onPressed: _undoManager.canUndo || _undoManager.canRedo
                ? () => _undoManager.clear()
                : null,
            child: const Text('Clear History'),
          ),

          const SizedBox(width: 16),
        ],
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          controller: _controller,
          editController: _editController,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
        ),
      ),
    );
  }
}
