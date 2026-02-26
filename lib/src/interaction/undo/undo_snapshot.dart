import '../../core/core.dart';

/// Captures and restores cell state within a range for undo/redo.
class UndoSnapshot {
  UndoSnapshot._();

  /// Captures a snapshot of all cell data and merges within [range].
  ///
  /// Collects values, styles, formats, and rich text from sparse iterators,
  /// building one [Cell] per unique coordinate. Also collects merge regions.
  ///
  /// Returns a tuple of (cells map, merge region list).
  static (Map<CellCoordinate, Cell>, List<CellRange>) capture(
    WorksheetData data,
    CellRange range,
  ) {
    final cells = <CellCoordinate, Cell>{};

    // Collect values
    for (final entry in data.getCellsInRange(range)) {
      final coord = entry.key;
      cells[coord] = Cell(value: entry.value);
    }

    // Merge in styles
    for (final entry in data.getStylesInRange(range)) {
      final coord = entry.key;
      final existing = cells[coord];
      cells[coord] = Cell(
        value: existing?.value,
        style: entry.value,
        format: existing?.format,
        richText: existing?.richText,
      );
    }

    // Merge in formats
    for (final entry in data.getFormatsInRange(range)) {
      final coord = entry.key;
      final existing = cells[coord];
      cells[coord] = Cell(
        value: existing?.value,
        style: existing?.style,
        format: entry.value,
        richText: existing?.richText,
      );
    }

    // Merge in rich text
    for (final entry in data.getRichTextInRange(range)) {
      final coord = entry.key;
      final existing = cells[coord];
      cells[coord] = Cell(
        value: existing?.value,
        style: existing?.style,
        format: existing?.format,
        richText: entry.value,
      );
    }

    // Collect merge regions
    final merges = data.mergedCells
        .regionsInRange(range)
        .map((r) => r.range)
        .toList();

    return (cells, merges);
  }

  /// Restores cell data and merges within [range] from a snapshot.
  ///
  /// Clears the range (values, styles, formats, rich text) and unmerges,
  /// then writes the snapshot cells back via [batchUpdate] and re-creates
  /// the merge regions.
  static void restore(
    WorksheetData data,
    CellRange range,
    Map<CellCoordinate, Cell> cells,
    List<CellRange> merges,
  ) {
    // Clear existing data in range
    data.clearRange(range);
    data.unmergeCellsInRange(range);

    // Write snapshot cells back
    if (cells.isNotEmpty) {
      data.batchUpdate((batch) {
        for (final entry in cells.entries) {
          final coord = entry.key;
          final cell = entry.value;
          if (cell.value != null) batch.setCell(coord, cell.value);
          if (cell.style != null) batch.setStyle(coord, cell.style);
          if (cell.format != null) batch.setFormat(coord, cell.format);
          if (cell.richText != null) batch.setRichText(coord, cell.richText);
        }
      });
    }

    // Recreate merges
    for (final merge in merges) {
      data.mergeCells(merge);
    }
  }
}
