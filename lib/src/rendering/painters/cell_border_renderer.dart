import 'dart:ui';

import '../../core/data/merged_cell_registry.dart';
import '../../core/data/worksheet_data.dart';
import '../../core/models/border_resolver.dart';
import '../../core/models/cell_coordinate.dart';
import '../../core/models/cell_style.dart';
import 'border_painter.dart';

/// Shared border rendering logic used by both [TilePainter] and [FrozenLayer].
///
/// Iterates over a cell range, resolves border conflicts with neighbors,
/// and delegates line drawing to [BorderPainter].
class CellBorderRenderer {
  const CellBorderRenderer._();

  /// Renders cell borders for the given range onto [canvas].
  ///
  /// Parameters:
  /// - [canvas]: The canvas to draw on.
  /// - [borderPaint]: A pre-allocated [Paint] for border strokes.
  /// - [data]: The worksheet data source for reading cell styles.
  /// - [mergedCells]: Optional merged cell registry for merge-aware rendering.
  /// - [startRow], [endRow], [startCol], [endCol]: The cell range to render.
  /// - [maxRow], [maxCol]: Maximum valid row/column indices for neighbor lookups.
  /// - [getBounds]: Callback that returns the drawing bounds for a cell,
  ///   already transformed to the target coordinate system (e.g., tile-local
  ///   or zoom-scaled viewport coords).
  /// - [widthScale]: Multiplier for border widths. TilePainter passes
  ///   the zoom-bucket gridline stroke width; FrozenLayer passes 1.0.
  /// Returns the rendering pass for a border style.
  ///
  /// Pass 0: normal/single (non-double, width <= 1)
  /// Pass 1: thick (non-double, width > 1)
  /// Pass 2: double (lineStyle == double)
  ///
  /// Higher-priority borders paint in later passes so they aren't
  /// overwritten at perpendicular junctions.
  static int _borderPass(BorderStyle border) {
    if (border.lineStyle == BorderLineStyle.double) return 2;
    if (border.width > 1.0) return 1;
    return 0;
  }

  static void renderBorders({
    required Canvas canvas,
    required Paint borderPaint,
    required WorksheetData data,
    required MergedCellRegistry? mergedCells,
    required int startRow,
    required int endRow,
    required int startCol,
    required int endCol,
    required int maxRow,
    required int maxCol,
    required Rect Function(CellCoordinate) getBounds,
    required double widthScale,
  }) {
    // 3-pass rendering: normal (pass 0) → thick (pass 1) → double (pass 2).
    // Higher-priority borders paint last so they aren't overwritten at
    // perpendicular junctions.
    for (var pass = 0; pass < 3; pass++) {
      final renderedBorderAnchors = <CellCoordinate>{};

      for (var row = startRow; row <= endRow; row++) {
        for (var col = startCol; col <= endCol; col++) {
          final coord = CellCoordinate(row, col);

          // For merged cells, resolve to anchor for border rendering.
          final region = mergedCells?.getRegion(coord);
          final renderCoord = region?.anchor ?? coord;

          if (region != null) {
            if (renderedBorderAnchors.contains(renderCoord)) continue;
            renderedBorderAnchors.add(renderCoord);
          }

          final style = data.getStyle(renderCoord);
          final borders = style?.borders;
          if (borders == null || borders.isNone) continue;

          final localBounds = getBounds(renderCoord);

          // Use merge region edges for conflict resolution neighbors.
          final topEdgeRow = region?.range.startRow ?? renderCoord.row;
          final bottomEdgeRow = region?.range.endRow ?? renderCoord.row;
          final leftEdgeCol = region?.range.startColumn ?? renderCoord.column;
          final rightEdgeCol = region?.range.endColumn ?? renderCoord.column;

          // Look up perpendicular borders on the OTHER side of each junction
          // (perpB). These tell BorderPainter whether a double border continues
          // through the junction (both perpA and perpB double → + junction) or
          // terminates (only one → L/T junction).

          // Vertical perp going UP from top-edge junctions.
          final topLeftPerpUp = topEdgeRow > 0
              ? data.getStyle(CellCoordinate(topEdgeRow - 1, leftEdgeCol))
                  ?.borders?.left
              : null;
          final topRightPerpUp = topEdgeRow > 0
              ? data.getStyle(CellCoordinate(topEdgeRow - 1, rightEdgeCol))
                  ?.borders?.right
              : null;
          // Vertical perp going DOWN from bottom-edge junctions.
          final bottomLeftPerpDown = bottomEdgeRow < maxRow
              ? data.getStyle(CellCoordinate(bottomEdgeRow + 1, leftEdgeCol))
                  ?.borders?.left
              : null;
          final bottomRightPerpDown = bottomEdgeRow < maxRow
              ? data.getStyle(CellCoordinate(bottomEdgeRow + 1, rightEdgeCol))
                  ?.borders?.right
              : null;
          // Horizontal perp going LEFT from left-edge junctions.
          final topLeftPerpLeft = leftEdgeCol > 0
              ? data.getStyle(CellCoordinate(topEdgeRow, leftEdgeCol - 1))
                  ?.borders?.top
              : null;
          final bottomLeftPerpLeft = leftEdgeCol > 0
              ? data.getStyle(CellCoordinate(bottomEdgeRow, leftEdgeCol - 1))
                  ?.borders?.bottom
              : null;
          // Horizontal perp going RIGHT from right-edge junctions.
          final topRightPerpRight = rightEdgeCol < maxCol
              ? data.getStyle(CellCoordinate(topEdgeRow, rightEdgeCol + 1))
                  ?.borders?.top
              : null;
          final bottomRightPerpRight = rightEdgeCol < maxCol
              ? data.getStyle(CellCoordinate(bottomEdgeRow, rightEdgeCol + 1))
                  ?.borders?.bottom
              : null;

          _renderTopBorder(
            canvas, borderPaint, data, borders, localBounds,
            topEdgeRow, renderCoord.column, widthScale, pass,
            startPerpB: topLeftPerpUp,
            endPerpB: topRightPerpUp,
          );
          _renderBottomBorder(
            canvas, borderPaint, data, borders, localBounds,
            bottomEdgeRow, renderCoord.column, maxRow, widthScale, pass,
            startPerpB: bottomLeftPerpDown,
            endPerpB: bottomRightPerpDown,
          );
          _renderLeftBorder(
            canvas, borderPaint, data, borders, localBounds,
            renderCoord.row, leftEdgeCol, widthScale, pass,
            startPerpB: topLeftPerpLeft,
            endPerpB: bottomLeftPerpLeft,
          );
          _renderRightBorder(
            canvas, borderPaint, data, borders, localBounds,
            renderCoord.row, rightEdgeCol, maxCol, widthScale, pass,
            startPerpB: topRightPerpRight,
            endPerpB: bottomRightPerpRight,
          );
        }
      }
    }
  }

  static void _renderTopBorder(
    Canvas canvas,
    Paint borderPaint,
    WorksheetData data,
    CellBorders borders,
    Rect localBounds,
    int topEdgeRow,
    int column,
    double widthScale,
    int pass, {
    BorderStyle? startPerpB,
    BorderStyle? endPerpB,
  }) {
    if (borders.top.isNone) return;

    final resolved = topEdgeRow > 0
        ? BorderResolver.resolve(
            data.getStyle(CellCoordinate(topEdgeRow - 1, column))
                    ?.borders?.bottom ??
                BorderStyle.none,
            borders.top,
          )
        : borders.top;
    if (resolved.isNone) return;
    if (_borderPass(resolved) != pass) return;

    final effectiveWidth = resolved.width * widthScale;
    final totalWidth = resolved.lineStyle == BorderLineStyle.double
        ? effectiveWidth * 3.0
        : effectiveWidth;
    borderPaint
      ..color = resolved.color
      ..strokeWidth = effectiveWidth;
    final y = localBounds.top.roundToDouble() + 0.5;
    BorderPainter.drawBorderEdge(
      canvas,
      Offset(localBounds.left, y),
      Offset(localBounds.right, y),
      borderPaint,
      resolved.lineStyle,
      effectiveWidth,
      startExt: (totalWidth - 1.0) / 2.0,
      endExt: (totalWidth + 1.0) / 2.0,
      outerSign: -1,
      startJunctionPerpA: borders.left,
      startJunctionPerpB: startPerpB,
      endJunctionPerpA: borders.right,
      endJunctionPerpB: endPerpB,
    );
  }

  static void _renderBottomBorder(
    Canvas canvas,
    Paint borderPaint,
    WorksheetData data,
    CellBorders borders,
    Rect localBounds,
    int bottomEdgeRow,
    int column,
    int maxRow,
    double widthScale,
    int pass, {
    BorderStyle? startPerpB,
    BorderStyle? endPerpB,
  }) {
    if (borders.bottom.isNone) return;

    final neighborTop = bottomEdgeRow < maxRow
        ? data
                .getStyle(CellCoordinate(bottomEdgeRow + 1, column))
                ?.borders
                ?.top ??
            BorderStyle.none
        : BorderStyle.none;
    final resolved = bottomEdgeRow < maxRow
        ? BorderResolver.resolve(borders.bottom, neighborTop)
        : borders.bottom;
    if (resolved.isNone) return;
    if (_borderPass(resolved) != pass) return;

    final effectiveWidth = resolved.width * widthScale;
    final totalWidth = resolved.lineStyle == BorderLineStyle.double
        ? effectiveWidth * 3.0
        : effectiveWidth;
    final isSharedDouble =
        resolved.lineStyle == BorderLineStyle.double && !neighborTop.isNone;
    borderPaint
      ..color = resolved.color
      ..strokeWidth = effectiveWidth;
    final y = localBounds.bottom.roundToDouble() + 0.5;
    BorderPainter.drawBorderEdge(
      canvas,
      Offset(localBounds.left, y),
      Offset(localBounds.right, y),
      borderPaint,
      resolved.lineStyle,
      effectiveWidth,
      startExt: (totalWidth - 1.0) / 2.0,
      endExt: (totalWidth + 1.0) / 2.0,
      outerSign: isSharedDouble ? -1 : 1,
      startJunctionPerpA: borders.left,
      startJunctionPerpB: startPerpB,
      endJunctionPerpA: borders.right,
      endJunctionPerpB: endPerpB,
    );
  }

  static void _renderLeftBorder(
    Canvas canvas,
    Paint borderPaint,
    WorksheetData data,
    CellBorders borders,
    Rect localBounds,
    int row,
    int leftEdgeCol,
    double widthScale,
    int pass, {
    BorderStyle? startPerpB,
    BorderStyle? endPerpB,
  }) {
    if (borders.left.isNone) return;

    final resolved = leftEdgeCol > 0
        ? BorderResolver.resolve(
            data.getStyle(CellCoordinate(row, leftEdgeCol - 1))
                    ?.borders?.right ??
                BorderStyle.none,
            borders.left,
          )
        : borders.left;
    if (resolved.isNone) return;
    if (_borderPass(resolved) != pass) return;

    final effectiveWidth = resolved.width * widthScale;
    final totalWidth = resolved.lineStyle == BorderLineStyle.double
        ? effectiveWidth * 3.0
        : effectiveWidth;
    borderPaint
      ..color = resolved.color
      ..strokeWidth = effectiveWidth;
    final x = localBounds.left.roundToDouble() + 0.5;
    BorderPainter.drawBorderEdge(
      canvas,
      Offset(x, localBounds.top),
      Offset(x, localBounds.bottom),
      borderPaint,
      resolved.lineStyle,
      effectiveWidth,
      startExt: (totalWidth - 1.0) / 2.0,
      endExt: (totalWidth + 1.0) / 2.0,
      outerSign: -1,
      startJunctionPerpA: borders.top,
      startJunctionPerpB: startPerpB,
      endJunctionPerpA: borders.bottom,
      endJunctionPerpB: endPerpB,
    );
  }

  static void _renderRightBorder(
    Canvas canvas,
    Paint borderPaint,
    WorksheetData data,
    CellBorders borders,
    Rect localBounds,
    int row,
    int rightEdgeCol,
    int maxCol,
    double widthScale,
    int pass, {
    BorderStyle? startPerpB,
    BorderStyle? endPerpB,
  }) {
    if (borders.right.isNone) return;

    final neighborLeft = rightEdgeCol < maxCol
        ? data
                .getStyle(CellCoordinate(row, rightEdgeCol + 1))
                ?.borders
                ?.left ??
            BorderStyle.none
        : BorderStyle.none;
    final resolved = rightEdgeCol < maxCol
        ? BorderResolver.resolve(borders.right, neighborLeft)
        : borders.right;
    if (resolved.isNone) return;
    if (_borderPass(resolved) != pass) return;

    final effectiveWidth = resolved.width * widthScale;
    final totalWidth = resolved.lineStyle == BorderLineStyle.double
        ? effectiveWidth * 3.0
        : effectiveWidth;
    final isSharedDouble =
        resolved.lineStyle == BorderLineStyle.double && !neighborLeft.isNone;
    borderPaint
      ..color = resolved.color
      ..strokeWidth = effectiveWidth;
    final x = localBounds.right.roundToDouble() + 0.5;
    BorderPainter.drawBorderEdge(
      canvas,
      Offset(x, localBounds.top),
      Offset(x, localBounds.bottom),
      borderPaint,
      resolved.lineStyle,
      effectiveWidth,
      startExt: (totalWidth - 1.0) / 2.0,
      endExt: (totalWidth + 1.0) / 2.0,
      outerSign: isSharedDouble ? -1 : 1,
      startJunctionPerpA: borders.top,
      startJunctionPerpB: startPerpB,
      endJunctionPerpA: borders.bottom,
      endJunctionPerpB: endPerpB,
    );
  }
}
