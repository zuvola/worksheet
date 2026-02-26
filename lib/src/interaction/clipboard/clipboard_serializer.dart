import 'package:any_date/any_date.dart';

import '../../core/core.dart';

/// Abstract interface for clipboard data conversion.
///
/// Override to support custom formats (binary, HTML, etc.).
abstract class ClipboardSerializer {
  /// Convert selected cells to clipboard text.
  String serialize(CellRange range, WorksheetData data);

  /// Parse clipboard text into a grid of [CellValue]s.
  ///
  /// Returns rows x columns of `CellValue?` (null = empty cell).
  List<List<CellValue?>> deserialize(String text);
}

/// Default clipboard serializer using tab-separated values.
///
/// Compatible with Excel and Google Sheets clipboard format:
/// - Columns separated by tab (`\t`)
/// - Rows separated by newline (`\n`)
class TsvClipboardSerializer implements ClipboardSerializer {
  /// Date parser for type detection during clipboard paste.
  final AnyDate? dateParser;

  const TsvClipboardSerializer({this.dateParser});

  @override
  String serialize(CellRange range, WorksheetData data) {
    // For very large ranges (e.g. select-all at Excel scale), find the
    // populated bounding box and serialize only that sub-range.
    if (range.cellCount > 10000000) {
      return _serializeSparse(range, data);
    }

    final buffer = StringBuffer();
    for (int row = range.startRow; row <= range.endRow; row++) {
      if (row > range.startRow) buffer.write('\n');
      for (int col = range.startColumn; col <= range.endColumn; col++) {
        if (col > range.startColumn) buffer.write('\t');
        final coord = CellCoordinate(row, col);
        final value = data.getCell(coord);
        if (value != null) {
          final format = data.getFormat(coord);
          final cell = Cell(value: value, format: format);
          buffer.write(cell.displayValue);
        }
      }
    }
    return buffer.toString();
  }

  /// Serializes a large range by iterating only populated cells.
  ///
  /// Finds the bounding box of populated data, and if still too large
  /// (> 10M cells), serializes only the populated cells in sorted TSV.
  String _serializeSparse(CellRange range, WorksheetData data) {
    // Collect populated cells and compute bounding box.
    final cells = <CellCoordinate, Cell>{};
    int? minRow, maxRow, minCol, maxCol;
    for (final entry in data.getCellsInRange(range)) {
      final coord = entry.key;
      final format = data.getFormat(coord);
      cells[coord] = Cell(value: entry.value, format: format);
      if (minRow == null || coord.row < minRow) minRow = coord.row;
      if (maxRow == null || coord.row > maxRow) maxRow = coord.row;
      if (minCol == null || coord.column < minCol) minCol = coord.column;
      if (maxCol == null || coord.column > maxCol) maxCol = coord.column;
    }
    if (minRow == null) return '';

    final bounds = CellRange(minRow, minCol!, maxRow!, maxCol!);

    // If bounding box is manageable, serialize it directly.
    if (bounds.cellCount <= 10000000) {
      final buffer = StringBuffer();
      for (int row = bounds.startRow; row <= bounds.endRow; row++) {
        if (row > bounds.startRow) buffer.write('\n');
        for (int col = bounds.startColumn; col <= bounds.endColumn; col++) {
          if (col > bounds.startColumn) buffer.write('\t');
          final cell = cells[CellCoordinate(row, col)];
          if (cell != null) {
            buffer.write(cell.displayValue);
          }
        }
      }
      return buffer.toString();
    }

    // Bounding box still too large — serialize only populated rows/cols.
    // Group cells by row, sort rows, then within each row sort by column.
    final byRow = <int, List<MapEntry<int, Cell>>>{};
    for (final entry in cells.entries) {
      byRow
          .putIfAbsent(entry.key.row, () => [])
          .add(MapEntry(entry.key.column, entry.value));
    }
    final sortedRows = byRow.keys.toList()..sort();
    final buffer = StringBuffer();
    for (int i = 0; i < sortedRows.length; i++) {
      if (i > 0) buffer.write('\n');
      final rowCells = byRow[sortedRows[i]]!
        ..sort((a, b) => a.key.compareTo(b.key));
      for (int j = 0; j < rowCells.length; j++) {
        if (j > 0) buffer.write('\t');
        buffer.write(rowCells[j].value.displayValue);
      }
    }
    return buffer.toString();
  }

  @override
  List<List<CellValue?>> deserialize(String text) {
    if (text.isEmpty) return [];

    final rows = text.split('\n');
    return rows.map((row) {
      final columns = row.split('\t');
      return columns.map(_parseValue).toList();
    }).toList();
  }

  CellValue? _parseValue(String text) =>
      CellValue.parse(text, allowFormulas: false, dateParser: dateParser);
}
