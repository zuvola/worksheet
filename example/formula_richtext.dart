/// Example: formula cells with rich text styling.
///
/// Demonstrates the fix for formula cells whose richText spans reflect the
/// evaluated display value. Before the fix, opening the editor on a formula
/// cell would show the display value ("126") instead of the formula ("=A1*3").
///
/// Architecture: [FormulaData] wraps a [SparseWorksheetData] and overrides
/// [getCell] to return evaluated results for formula cells. The Worksheet
/// uses this as both `data` (for rendering) and sees formulas via the
/// separate `rawData` (for editing). No change-stream re-evaluation needed.
///
/// Run: flutter run -t example/formula_richtext.dart
library;

import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: FormulaRichTextDemo()));

/// Worksheet data source that evaluates formulas on read.
///
/// Stores formulas in the underlying [SparseWorksheetData] and returns
/// evaluated results from [getCell]. [getRichText] returns a cell-level
/// style span for formula cells so the result inherits bold+blue styling.
class FormulaData extends SparseWorksheetData {
  FormulaData({required super.rowCount, required super.columnCount});

  @override
  CellValue? getCell(CellCoordinate coord) {
    final raw = super.getCell(coord);
    if (raw == null || !raw.isFormula) return raw;
    final result = _eval(raw.rawValue as String);
    return result != null
        ? CellValue.number(result)
        : const CellValue.error('#ERROR');
  }

  @override
  List<TextSpan>? getRichText(CellCoordinate coord) {
    final stored = super.getRichText(coord);
    if (stored != null) return stored;
    // Auto-generate cell-level bold+blue style for formula cells.
    final raw = super.getCell(coord);
    if (raw != null && raw.isFormula) {
      return const [
        TextSpan(
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ];
    }
    return null;
  }

  /// Returns the raw (unevaluated) cell value — formulas stay as formulas.
  CellValue? getRawCell(CellCoordinate coord) => super.getCell(coord);

  // -- Tiny formula evaluator --

  double? _eval(String formula) {
    if (!formula.startsWith('=')) return null;
    final expr = formula.substring(1);
    if (expr.contains('+')) {
      return _evalBinop(expr, '+', (a, b) => a + b, 0);
    }
    if (expr.contains('*')) {
      return _evalBinop(expr, '*', (a, b) => a * b, 1);
    }
    return _resolveRef(expr.trim());
  }

  double? _evalBinop(
    String expr,
    String op,
    double Function(double, double) combine,
    double identity,
  ) {
    double result = identity;
    for (final p in expr.split(op)) {
      final v = _resolveRef(p.trim());
      if (v == null) return null;
      result = combine(result, v);
    }
    return result;
  }

  double? _resolveRef(String ref) {
    final match = RegExp(r'^([A-Z])(\d+)$').firstMatch(ref);
    if (match == null) return double.tryParse(ref);
    final col = match.group(1)!.codeUnitAt(0) - 65;
    final row = int.parse(match.group(2)!) - 1;
    // Use getCell (which recursively evaluates formulas).
    final value = getCell(CellCoordinate(row, col));
    if (value == null) return null;
    if (value.type == CellValueType.number) return value.rawValue as double;
    return double.tryParse(value.displayValue);
  }
}

/// Thin read-only wrapper that exposes raw (unevaluated) cell values.
///
/// Passed as [Worksheet.rawData] so the editor shows the formula string
/// instead of the evaluated result.
class RawDataView extends SparseWorksheetData {
  final FormulaData _source;

  RawDataView(this._source)
    : super(rowCount: _source.rowCount, columnCount: _source.columnCount);

  @override
  CellValue? getCell(CellCoordinate coord) => _source.getRawCell(coord);
}

// ---------------------------------------------------------------------------

class FormulaRichTextDemo extends StatefulWidget {
  const FormulaRichTextDemo({super.key});

  @override
  State<FormulaRichTextDemo> createState() => _FormulaRichTextDemoState();
}

class _FormulaRichTextDemoState extends State<FormulaRichTextDemo> {
  late final FormulaData _data;
  late final RawDataView _rawView;
  late final EditController _editController;

  @override
  void initState() {
    super.initState();
    _editController = EditController();

    _data = FormulaData(rowCount: 100, columnCount: 10);

    // Headers
    _data.setCell(const CellCoordinate(0, 0), const CellValue.text('Item'));
    _data.setCell(const CellCoordinate(0, 1), const CellValue.text('Price'));
    _data.setCell(const CellCoordinate(0, 2), const CellValue.text('Qty'));
    _data.setCell(const CellCoordinate(0, 3), const CellValue.text('Total'));
    for (var col = 0; col < 4; col++) {
      final coord = CellCoordinate(0, col);
      final text = _data.getCell(coord)?.displayValue ?? '';
      _data.setRichText(coord, [
        TextSpan(
          text: text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);
    }

    // Data rows
    _data.setCell(const CellCoordinate(1, 0), const CellValue.text('Apples'));
    _data.setCell(const CellCoordinate(1, 1), CellValue.number(3));
    _data.setCell(const CellCoordinate(1, 2), CellValue.number(42));
    _data.setCell(
      const CellCoordinate(1, 3),
      const CellValue.formula('=B2*C2'),
    );

    _data.setCell(const CellCoordinate(2, 0), const CellValue.text('Bananas'));
    _data.setCell(const CellCoordinate(2, 1), CellValue.number(1.5));
    _data.setCell(const CellCoordinate(2, 2), CellValue.number(100));
    _data.setCell(
      const CellCoordinate(2, 3),
      const CellValue.formula('=B3*C3'),
    );

    _data.setCell(
      const CellCoordinate(3, 0),
      const CellValue.text('Cherries'),
    );
    _data.setCell(const CellCoordinate(3, 1), CellValue.number(8));
    _data.setCell(const CellCoordinate(3, 2), CellValue.number(10));
    _data.setCell(
      const CellCoordinate(3, 3),
      const CellValue.formula('=B4*C4'),
    );

    // Summary
    _data.setCell(
      const CellCoordinate(5, 2),
      const CellValue.text('Grand Total'),
    );
    _data.setRichText(const CellCoordinate(5, 2), [
      const TextSpan(
        text: 'Grand Total',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
    _data.setCell(
      const CellCoordinate(5, 3),
      const CellValue.formula('=D2+D3+D4'),
    );

    _rawView = RawDataView(_data);
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
        title: const Text('Formula + Rich Text Demo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Text(
              'Double-click a blue formula cell (Total column) — '
              'the editor should show the formula (e.g. "=B2*C2"), '
              'not the display value (e.g. "126").',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          rawData: _rawView,
          editController: _editController,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
        ),
      ),
    );
  }
}
