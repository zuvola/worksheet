import 'package:flutter/painting.dart';

import '../models/models.dart';
import 'data_change_event.dart';
import 'merged_cell_registry.dart';
import 'worksheet_data.dart';

/// A [WorksheetData] wrapper that forwards every method to an [inner] instance.
///
/// Extend this class to create decorators that override only the methods they
/// need — everything else delegates automatically. This eliminates the ~100
/// lines of mechanical forwarding boilerplate that every `WorksheetData`
/// wrapper would otherwise require.
///
/// ```dart
/// class LoggingWorksheetData extends DelegatingWorksheetData {
///   LoggingWorksheetData(super.inner);
///
///   @override
///   void setCell(CellCoordinate coord, CellValue? value) {
///     print('setCell($coord, $value)');
///     super.setCell(coord, value);
///   }
/// }
/// ```
///
/// By default, [dispose] is a no-op — the inner data source owns its own
/// lifecycle. Override [dispose] to clean up resources owned by the subclass.
class DelegatingWorksheetData implements WorksheetData {
  /// The wrapped data source. All methods delegate to this by default.
  final WorksheetData inner;

  /// Creates a delegating wrapper around [inner].
  DelegatingWorksheetData(this.inner);

  @override
  CellValue? getCell(CellCoordinate coord) => inner.getCell(coord);

  @override
  CellStyle? getStyle(CellCoordinate coord) => inner.getStyle(coord);

  @override
  void setCell(CellCoordinate coord, CellValue? value) =>
      inner.setCell(coord, value);

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) =>
      inner.setStyle(coord, style);

  @override
  CellFormat? getFormat(CellCoordinate coord) => inner.getFormat(coord);

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) =>
      inner.setFormat(coord, format);

  @override
  List<TextSpan>? getRichText(CellCoordinate coord) =>
      inner.getRichText(coord);

  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) =>
      inner.setRichText(coord, richText);

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) =>
      inner.batchUpdate(updates);

  @override
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) =>
      inner.batchUpdateAsync(updates);

  @override
  Stream<DataChangeEvent> get changes => inner.changes;

  @override
  int get rowCount => inner.rowCount;

  @override
  int get columnCount => inner.columnCount;

  @override
  bool hasValue(CellCoordinate coord) => inner.hasValue(coord);

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) =>
      inner.getCellsInRange(range);

  @override
  void clearRange(CellRange range) => inner.clearRange(range);

  @override
  void clearRichTextInRange(CellRange range) =>
      inner.clearRichTextInRange(range);

  @override
  Iterable<MapEntry<CellCoordinate, List<TextSpan>>> getRichTextInRange(
    CellRange range,
  ) =>
      inner.getRichTextInRange(range);

  @override
  Iterable<MapEntry<CellCoordinate, CellStyle>> getStylesInRange(
    CellRange range,
  ) =>
      inner.getStylesInRange(range);

  @override
  Iterable<MapEntry<CellCoordinate, CellFormat>> getFormatsInRange(
    CellRange range,
  ) =>
      inner.getFormatsInRange(range);

  @override
  CellRange? smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) =>
      inner.smartFill(range, destination, valueGenerator);

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) =>
      inner.fillRange(source, range, valueGenerator);

  @override
  MergedCellRegistry get mergedCells => inner.mergedCells;

  @override
  void mergeCells(CellRange range) => inner.mergeCells(range);

  @override
  void unmergeCells(CellCoordinate cell) => inner.unmergeCells(cell);

  @override
  void unmergeCellsInRange(CellRange range) =>
      inner.unmergeCellsInRange(range);

  @override
  void moveMerges(CellRange source, CellCoordinate destination) =>
      inner.moveMerges(source, destination);

  @override
  void replicateMerges({
    required CellRange sourceRange,
    required CellRange targetRange,
    required bool vertical,
  }) =>
      inner.replicateMerges(
        sourceRange: sourceRange,
        targetRange: targetRange,
        vertical: vertical,
      );

  @override
  int? findNextPopulatedRow(int column, int fromRow) =>
      inner.findNextPopulatedRow(column, fromRow);

  @override
  int? findPrevPopulatedRow(int column, int fromRow) =>
      inner.findPrevPopulatedRow(column, fromRow);

  @override
  int? findNextPopulatedColumn(int row, int fromColumn) =>
      inner.findNextPopulatedColumn(row, fromColumn);

  @override
  int? findPrevPopulatedColumn(int row, int fromColumn) =>
      inner.findPrevPopulatedColumn(row, fromColumn);

  /// No-op by default — the [inner] data source owns its own lifecycle.
  ///
  /// Override to clean up resources owned by the subclass.
  @override
  void dispose() {}
}
