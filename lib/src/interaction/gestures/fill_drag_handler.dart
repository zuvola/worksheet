import 'dart:math' as math;
import 'dart:ui';

import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_range.dart';
import '../hit_testing/hit_tester.dart';

/// The axis along which a fill drag is constrained.
enum FillAxis { vertical, horizontal }

/// Callback for when the fill preview range changes during drag.
typedef OnFillPreviewUpdate = void Function(CellRange previewRange);

/// Callback for when a fill drag completes.
typedef OnFillComplete = void Function(
    CellRange sourceRange, CellCoordinate destination);

/// Callback for when a fill drag is cancelled.
typedef OnFillCancel = void Function();

/// Handles fill-handle drag operations.
///
/// Encapsulates the fill-specific state (source range, axis lock, last
/// destination) and the axis-constraint algorithm. Created and owned by
/// [WorksheetGestureHandler].
class FillDragHandler {
  /// The hit tester for coordinate resolution.
  final WorksheetHitTester hitTester;

  /// Callback when the fill preview range changes during drag.
  final OnFillPreviewUpdate? onFillPreviewUpdate;

  /// Callback when a fill drag completes.
  final OnFillComplete? onFillComplete;

  /// Callback when a fill drag is cancelled.
  final OnFillCancel? onFillCancel;

  // Fill-specific state
  bool _isFilling = false;
  CellRange? _fillSourceRange;
  CellCoordinate? _lastFillDestination;
  FillAxis? _fillAxis;
  Offset? _dragStartPosition;

  /// Creates a fill drag handler.
  FillDragHandler({
    required this.hitTester,
    this.onFillPreviewUpdate,
    this.onFillComplete,
    this.onFillCancel,
  });

  /// Whether a fill drag is in progress.
  bool get isFilling => _isFilling;

  /// Starts a fill drag.
  ///
  /// [selectionRange] is the current selection that becomes the fill source.
  /// [dragStartPosition] is the screen position where the drag started.
  void start(CellRange? selectionRange, Offset dragStartPosition) {
    _isFilling = true;
    _fillSourceRange = selectionRange;
    _lastFillDestination = null;
    _fillAxis = null;
    _dragStartPosition = dragStartPosition;
  }

  /// Updates the fill drag with a new pointer position.
  void update(Offset position, Offset scrollOffset, double zoom) {
    if (_fillSourceRange == null) return;

    // Hit test without selectionRange to get the cell under the cursor
    final hit = hitTester.hitTest(
      position: position,
      scrollOffset: scrollOffset,
      zoom: zoom,
    );

    if (!hit.isCell || hit.cell == null) return;
    final cell = hit.cell!;
    final source = _fillSourceRange!;

    // Single-cell source: no series to disambiguate, expand freely
    final isSingleCell = source.startRow == source.endRow &&
        source.startColumn == source.endColumn;
    if (isSingleCell) {
      _lastFillDestination = cell;
      final previewRange = source.expand(cell);
      onFillPreviewUpdate?.call(previewRange);
      return;
    }

    // If cursor is still inside the source range and axis not yet locked, skip
    if (source.contains(cell) && _fillAxis == null) return;

    // Lock axis on first cell outside source range
    if (_fillAxis == null) {
      final outsideRow =
          cell.row < source.startRow || cell.row > source.endRow;
      final outsideCol =
          cell.column < source.startColumn || cell.column > source.endColumn;

      if (outsideRow && outsideCol) {
        // Diagonal — use pixel displacement to break tie
        final dx = (position.dx - _dragStartPosition!.dx).abs();
        final dy = (position.dy - _dragStartPosition!.dy).abs();
        _fillAxis = dy >= dx ? FillAxis.vertical : FillAxis.horizontal;
      } else if (outsideRow) {
        _fillAxis = FillAxis.vertical;
      } else if (outsideCol) {
        _fillAxis = FillAxis.horizontal;
      } else {
        return; // Still inside source (shouldn't reach here)
      }
    }

    // Constrain destination to the locked axis
    final CellCoordinate constrained;
    if (_fillAxis == FillAxis.vertical) {
      constrained = CellCoordinate(cell.row, source.endColumn);
    } else {
      constrained = CellCoordinate(source.endRow, cell.column);
    }

    _lastFillDestination = constrained;

    // Build the preview range: source expanded along the locked axis only
    final CellRange previewRange;
    if (_fillAxis == FillAxis.vertical) {
      previewRange = CellRange(
        math.min(source.startRow, constrained.row),
        source.startColumn,
        math.max(source.endRow, constrained.row),
        source.endColumn,
      );
    } else {
      previewRange = CellRange(
        source.startRow,
        math.min(source.startColumn, constrained.column),
        source.endRow,
        math.max(source.endColumn, constrained.column),
      );
    }

    onFillPreviewUpdate?.call(previewRange);
  }

  /// Ends the fill drag, completing or cancelling the operation.
  void end() {
    if (_lastFillDestination != null && _fillSourceRange != null) {
      onFillComplete?.call(_fillSourceRange!, _lastFillDestination!);
    } else {
      onFillCancel?.call();
    }
    reset();
  }

  /// Cancels the fill drag without completing.
  void cancel() {
    onFillCancel?.call();
    reset();
  }

  /// Resets all fill-specific state.
  void reset() {
    _isFilling = false;
    _fillSourceRange = null;
    _lastFillDestination = null;
    _fillAxis = null;
    _dragStartPosition = null;
  }
}
