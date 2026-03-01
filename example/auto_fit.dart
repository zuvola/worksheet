/// Example: auto-fit columns and rows with rich text styles and cell formats.
///
/// Demonstrates that double-clicking a column/row header separator correctly
/// auto-fits to the widest/tallest content, even when cells have:
/// - Cell-level rich text styles (bold, large font, color)
/// - CellFormat (currency, percentage, dates)
/// - Both combined
///
/// Run: flutter run -t example/auto_fit.dart
library;

import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: AutoFitDemo()));

class AutoFitDemo extends StatefulWidget {
  const AutoFitDemo({super.key});

  @override
  State<AutoFitDemo> createState() => _AutoFitDemoState();
}

class _AutoFitDemoState extends State<AutoFitDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;

  @override
  void initState() {
    super.initState();
    _editController = EditController();
    _data = SparseWorksheetData(rowCount: 30, columnCount: 8);
    _populateData();
  }

  void _populateData() {
    // --- Column A: Headers ---
    _header(0, 0, 'Scenario');
    _header(0, 1, 'Value');
    _header(0, 2, 'Notes');

    // --- Row 1: Plain text (baseline) ---
    _data.setCell(const CellCoordinate(1, 0), const CellValue.text('Plain'));
    _data.setCell(
      const CellCoordinate(1, 1),
      const CellValue.text('Hello World'),
    );
    _data.setCell(
      const CellCoordinate(1, 2),
      const CellValue.text('No styling — baseline width'),
    );

    // --- Row 2: Cell-level bold ---
    _data.setCell(const CellCoordinate(2, 0), const CellValue.text('Bold'));
    _data.setCell(
      const CellCoordinate(2, 1),
      const CellValue.text('Hello World'),
    );
    _data.setRichText(const CellCoordinate(2, 1), [
      const TextSpan(style: TextStyle(fontWeight: FontWeight.bold)),
    ]);
    _data.setCell(
      const CellCoordinate(2, 2),
      const CellValue.text('Cell-level bold style'),
    );

    // --- Row 3: Cell-level large font ---
    _data.setCell(
      const CellCoordinate(3, 0),
      const CellValue.text('Large font'),
    );
    _data.setCell(
      const CellCoordinate(3, 1),
      const CellValue.text('Hello World'),
    );
    _data.setRichText(const CellCoordinate(3, 1), [
      const TextSpan(style: TextStyle(fontSize: 24.0)),
    ]);
    _data.setCell(
      const CellCoordinate(3, 2),
      const CellValue.text('Cell-level fontSize: 24'),
    );

    // --- Row 4: Cell-level bold + blue + large ---
    _data.setCell(
      const CellCoordinate(4, 0),
      const CellValue.text('Bold+Blue+Large'),
    );
    _data.setCell(
      const CellCoordinate(4, 1),
      const CellValue.text('Hello World'),
    );
    _data.setRichText(const CellCoordinate(4, 1), [
      const TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1565C0),
          fontSize: 20.0,
        ),
      ),
    ]);
    _data.setCell(
      const CellCoordinate(4, 2),
      const CellValue.text('Bold + blue + 20px'),
    );

    // --- Row 6: Number formats header ---
    _header(6, 0, 'Format');
    _header(6, 1, 'Value');
    _header(6, 2, 'Notes');

    // --- Row 7: Raw number (baseline) ---
    _data.setCell(
      const CellCoordinate(7, 0),
      const CellValue.text('Raw number'),
    );
    _data.setCell(const CellCoordinate(7, 1), CellValue.number(1234567.89));
    _data.setCell(
      const CellCoordinate(7, 2),
      const CellValue.text('No format — shows "1234567.89"'),
    );

    // --- Row 8: Currency ---
    _data.setCell(const CellCoordinate(8, 0), const CellValue.text('Currency'));
    _data.setCell(const CellCoordinate(8, 1), CellValue.number(1234567.89));
    _data.setFormat(const CellCoordinate(8, 1), CellFormat.currency);
    _data.setCell(
      const CellCoordinate(8, 2),
      const CellValue.text(r'$#,##0.00 → "$1,234,567.89"'),
    );

    // --- Row 9: Percentage ---
    _data.setCell(
      const CellCoordinate(9, 0),
      const CellValue.text('Percentage'),
    );
    _data.setCell(const CellCoordinate(9, 1), CellValue.number(0.4256));
    _data.setFormat(const CellCoordinate(9, 1), CellFormat.percentageDecimal);
    _data.setCell(
      const CellCoordinate(9, 2),
      const CellValue.text('0.00% → "42.56%"'),
    );

    // --- Row 10: Number with thousands ---
    _data.setCell(
      const CellCoordinate(10, 0),
      const CellValue.text('Thousands'),
    );
    _data.setCell(const CellCoordinate(10, 1), CellValue.number(9876543));
    _data.setFormat(const CellCoordinate(10, 1), CellFormat.integer);
    _data.setCell(
      const CellCoordinate(10, 2),
      const CellValue.text('#,##0 → "9,876,543"'),
    );

    // --- Row 12: Combined header ---
    _header(12, 0, 'Combined');
    _header(12, 1, 'Value');
    _header(12, 2, 'Notes');

    // --- Row 13: Currency + bold ---
    _data.setCell(
      const CellCoordinate(13, 0),
      const CellValue.text('Currency + Bold'),
    );
    _data.setCell(const CellCoordinate(13, 1), CellValue.number(99999.99));
    _data.setFormat(const CellCoordinate(13, 1), CellFormat.currency);
    _data.setRichText(const CellCoordinate(13, 1), [
      const TextSpan(
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
      ),
    ]);
    _data.setCell(
      const CellCoordinate(13, 2),
      const CellValue.text('Currency format + bold green style'),
    );

    // --- Row 14: Percentage + large italic ---
    _data.setCell(
      const CellCoordinate(14, 0),
      const CellValue.text('Pct + Large Italic'),
    );
    _data.setCell(const CellCoordinate(14, 1), CellValue.number(0.95));
    _data.setFormat(const CellCoordinate(14, 1), CellFormat.percentageDecimal);
    _data.setRichText(const CellCoordinate(14, 1), [
      const TextSpan(
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontSize: 22.0,
          color: Color(0xFFE65100),
        ),
      ),
    ]);
    _data.setCell(
      const CellCoordinate(14, 2),
      const CellValue.text('Percentage + italic 22px orange'),
    );
  }

  void _header(int row, int col, String text) {
    final coord = CellCoordinate(row, col);
    _data.setCell(coord, CellValue.text(text));
    _data.setRichText(coord, [
      TextSpan(
        text: text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
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
        title: const Text('Auto-Fit: Rich Text + Formats'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Text(
              'Double-click a column header separator to auto-fit. '
              'Column B should resize to fit styled text and formatted numbers. '
              'Double-click a row header separator to auto-fit row height.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          editController: _editController,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
        ),
      ),
    );
  }
}
