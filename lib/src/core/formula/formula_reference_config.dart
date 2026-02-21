import 'package:a1/a1.dart';

import '../models/cell_coordinate.dart';
import '../models/cell_range.dart';
import 'formula_tokenizer.dart';

/// Configuration for formula cell reference editing.
///
/// When provided to a [Worksheet], enables Excel-style formula reference
/// editing: clicking cells inserts A1 references, dragging inserts ranges,
/// F4 cycles absolute/relative modes, and colored borders highlight
/// referenced cells.
///
/// All callbacks have sensible defaults. Set to `null` on the [Worksheet]
/// to disable formula reference editing entirely.
class FormulaReferenceConfig {
  /// Returns `true` when [text] represents a formula (edit mode should
  /// intercept cell clicks).
  ///
  /// Default: `text.startsWith('=')`.
  final bool Function(String text) isFormulaMode;

  /// Tokenizes a formula string into reference tokens.
  ///
  /// Default: [FormulaTokenizer.tokenize].
  final List<FormulaToken> Function(String formula) tokenize;

  /// Converts a cell coordinate to a reference string (e.g. "A1").
  ///
  /// Default: uses [A1.fromVector] with relative references.
  final String Function(CellCoordinate cell) cellToRef;

  /// Converts a cell range to a reference string (e.g. "A1:C5").
  ///
  /// Default: joins topLeft and bottomRight with `:`.
  final String Function(CellRange range) rangeToRef;

  const FormulaReferenceConfig({
    this.isFormulaMode = _defaultIsFormulaMode,
    this.tokenize = FormulaTokenizer.tokenize,
    this.cellToRef = _defaultCellToRef,
    this.rangeToRef = _defaultRangeToRef,
  });
}

bool _defaultIsFormulaMode(String text) => text.startsWith('=');

String _defaultCellToRef(CellCoordinate cell) =>
    A1.fromVector(cell.column, cell.row).toString();

String _defaultRangeToRef(CellRange range) {
  final start = A1.fromVector(range.startColumn, range.startRow).toString();
  final end = A1.fromVector(range.endColumn, range.endRow).toString();
  return '$start:$end';
}
