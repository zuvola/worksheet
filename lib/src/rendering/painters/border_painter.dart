import 'dart:ui';

import '../../core/models/cell_style.dart';

/// Shared utility for drawing border line styles on a Canvas.
///
/// Used by [CellBorderRenderer] (and transitively by TilePainter and
/// FrozenLayer) to draw individual border edges.
/// All methods snap to half-pixel positions for crisp rendering.
class BorderPainter {
  const BorderPainter._();

  /// Draws a border edge between [start] and [end] using the given [paint],
  /// [lineStyle], and [width].
  ///
  /// **Extension parameters** (choose one approach):
  ///
  /// 1. **Explicit extensions**: [startExt] and [endExt] extend the line along
  ///    its direction to close corner gaps caused by butt-cap line joins.
  ///
  /// 2. **Junction-aware extensions**: [startJunctionPerpA]/[startJunctionPerpB]
  ///    and [endJunctionPerpA]/[endJunctionPerpB] describe perpendicular borders
  ///    meeting at each endpoint. When provided, extension distances are computed
  ///    from the junction context instead of using [startExt]/[endExt].
  ///
  /// For double borders, [outerSign] indicates which sub-line is the outer one:
  /// -1 means the line offset in the negative perpendicular direction is outer
  /// (top/left borders), +1 means the positive direction (bottom/right borders).
  static void drawBorderEdge(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    BorderLineStyle lineStyle,
    double width, {
    double startExt = 0.0,
    double endExt = 0.0,
    int outerSign = -1,
    BorderStyle? startJunctionPerpA,
    BorderStyle? startJunctionPerpB,
    BorderStyle? endJunctionPerpA,
    BorderStyle? endJunctionPerpB,
  }) {
    // Compute extensions from junction context when provided.
    //
    // Skia uses half-open intervals [start, end) for stroke fills, so:
    //   - Start extension (inclusive): ext=N fills pixel at (base - N). No extra.
    //   - End extension (exclusive): ext=N only fills pixel at (base + N - 1).
    //     Add 1.0 to compensate when there IS a perpendicular border to meet.
    final effectiveStartExt =
        startJunctionPerpA != null || startJunctionPerpB != null
        ? _extensionFromJunction(
            startJunctionPerpA,
            startJunctionPerpB,
            width,
            lineStyle,
          )
        : startExt;
    final rawEndExt = endJunctionPerpA != null || endJunctionPerpB != null
        ? _extensionFromJunction(
            endJunctionPerpA,
            endJunctionPerpB,
            width,
            lineStyle,
          )
        : null;
    final effectiveEndExt = rawEndExt != null
        ? (rawEndExt > 0 ? rawEndExt + 1.0 : 0.0)
        : endExt;

    switch (lineStyle) {
      case BorderLineStyle.none:
        return;
      case BorderLineStyle.solid:
        final extStart = _extendStart(start, end, effectiveStartExt);
        final extEnd = _extendEnd(start, end, effectiveEndExt);
        canvas.drawLine(extStart, extEnd, paint);
      case BorderLineStyle.dotted:
        final extStart = _extendStart(start, end, effectiveStartExt);
        final extEnd = _extendEnd(start, end, effectiveEndExt);
        _drawDashedLine(canvas, extStart, extEnd, paint, width, width * 2);
      case BorderLineStyle.dashed:
        final extStart = _extendStart(start, end, effectiveStartExt);
        final extEnd = _extendEnd(start, end, effectiveEndExt);
        _drawDashedLine(canvas, extStart, extEnd, paint, width * 4, width * 2);
      case BorderLineStyle.double:
        // Inner sub-lines shorten when ANY perpendicular is double (preserves
        // gap at all junction types).
        final shortenInnerStart =
            _isDoublePerp(startJunctionPerpA) ||
            _isDoublePerp(startJunctionPerpB);
        final shortenInnerEnd =
            _isDoublePerp(endJunctionPerpA) || _isDoublePerp(endJunctionPerpB);
        // Outer sub-lines shorten only when BOTH perpendiculars are double
        // (the double border continues through the junction — + junctions).
        // At L-corners and T-junctions the outer lines extend through.
        final shortenOuterStart =
            _isDoublePerp(startJunctionPerpA) &&
            _isDoublePerp(startJunctionPerpB);
        final shortenOuterEnd =
            _isDoublePerp(endJunctionPerpA) && _isDoublePerp(endJunctionPerpB);
        _drawDoubleLine(
          canvas,
          start,
          end,
          paint,
          width,
          outerSign,
          shortenOuterStart ? 0.0 : effectiveStartExt,
          shortenOuterEnd ? 0.0 : effectiveEndExt,
          shortenOuterStart,
          shortenOuterEnd,
          shortenInnerStart,
          shortenInnerEnd,
        );
    }
  }

  /// Computes extension distance from perpendicular junction borders.
  ///
  /// Rules:
  /// - THICK or DOUBLE perpendicular → extend by half (visualWidth - 1) so
  ///   this edge fills through the junction area without overshooting.
  /// - Perpendicular has strictly greater raw [width] than this edge →
  ///   suppress extension (the wider border's stroke covers the junction).
  ///   Raw width is used (not visual width) so that a double border's
  ///   rendering spread doesn't make it "win" over a genuinely thicker solid.
  /// - THIN perpendicular (width=1) → no extension needed (0px).
  /// - NONE → no extension.
  ///
  /// When two perpendicular borders meet (A and B), use the maximum extension
  /// needed to cover both.
  static double _extensionFromJunction(
    BorderStyle? perpA,
    BorderStyle? perpB,
    double thisWidth,
    BorderLineStyle thisLineStyle,
  ) {
    final extA = _singlePerpExtension(perpA, thisWidth, thisLineStyle);
    final extB = _singlePerpExtension(perpB, thisWidth, thisLineStyle);
    return extA > extB ? extA : extB;
  }

  static double _singlePerpExtension(
    BorderStyle? perp,
    double thisWidth,
    BorderLineStyle thisLineStyle,
  ) {
    if (perp == null || perp.isNone) return 0.0;

    // Suppress when perpendicular has strictly higher junction priority.
    // Priority: lineStyle index first (double > solid > dashed > dotted),
    // then raw width within the same style.
    if (perp.lineStyle.index > thisLineStyle.index) return 0.0;
    if (perp.lineStyle.index == thisLineStyle.index && perp.width > thisWidth) {
      return 0.0;
    }

    final perpVisualWidth = perp.lineStyle == BorderLineStyle.double
        ? perp.width * 3.0
        : perp.width;

    // Extend by half the perpendicular border's visual width minus 1px.
    // The -1 accounts for Skia's pixel model where a stroke of width W
    // centered at coordinate C fills pixels C-W/2 .. C+W/2-1.  Without the
    // -1 the extension overshoots by 1px for even-width borders.
    return perpVisualWidth > 1.0 ? (perpVisualWidth - 1.0) / 2.0 : 0.0;
  }

  /// Returns true if [perp] is a double border whose gap channel must be
  /// preserved at the junction.
  static bool _isDoublePerp(BorderStyle? perp) {
    return perp != null &&
        !perp.isNone &&
        perp.lineStyle == BorderLineStyle.double;
  }

  static Offset _extendStart(Offset start, Offset end, double ext) {
    if (ext == 0) return start;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx.abs() > dy.abs()) {
      return Offset(start.dx - ext, start.dy);
    } else {
      return Offset(start.dx, start.dy - ext);
    }
  }

  static Offset _extendEnd(Offset start, Offset end, double ext) {
    if (ext == 0) return end;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx.abs() > dy.abs()) {
      return Offset(end.dx + ext, end.dy);
    } else {
      return Offset(end.dx, end.dy + ext);
    }
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLength,
    double gapLength,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLength = (dx * dx + dy * dy);
    if (totalLength == 0) return;
    final length = totalLength > 0
        ? (dx.abs() > dy.abs() ? dx.abs() : dy.abs())
        : 0.0;
    if (length == 0) return;

    final unitX = dx / length;
    final unitY = dy / length;
    final segmentLength = dashLength + gapLength;

    var distance = 0.0;
    while (distance < length) {
      final dashEnd = (distance + dashLength).clamp(0.0, length);
      canvas.drawLine(
        Offset(start.dx + unitX * distance, start.dy + unitY * distance),
        Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
        paint,
      );
      distance += segmentLength;
    }
  }

  static void _drawDoubleLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double width,
    int outerSign,
    double outerStartExt,
    double outerEndExt,
    bool shortenOuterStart,
    bool shortenOuterEnd,
    bool shortenInnerStart,
    bool shortenInnerEnd,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Outer sub-lines shorten only at + junctions (perpendicular double border
    // continues through). At L-corners and T-junctions, outer lines extend
    // through for a solid corner.
    //
    // Inner sub-lines shorten whenever ANY perpendicular double border exists,
    // preserving the gap channel at all junction types.
    //
    // Corner dots fill the 3x3 junction diagonals only at + junctions (when
    // outer is also shortened), since at L/T junctions the extended outer
    // sub-lines already cover those pixels.

    if (dx.abs() > dy.abs()) {
      // Horizontal line → offset vertically
      final outerY = start.dy + outerSign * width;
      final innerY = start.dy - outerSign * width;

      // The start (left) extension is reduced by 1px so the horizontal
      // outer aligns with the cell boundary rather than extending past it.
      // The vertical outer's extension already covers the corner pixel.
      final outerStartX = shortenOuterStart
          ? start.dx + 1.0
          : start.dx - (outerStartExt - 1.0).clamp(0.0, outerStartExt);
      final outerEndX = shortenOuterEnd ? end.dx : end.dx + outerEndExt;
      final innerStartX = shortenInnerStart ? start.dx + 1.0 : start.dx - 1.0;
      final innerEndX = shortenInnerEnd ? end.dx : end.dx + 1.0;

      canvas.drawLine(
        Offset(outerStartX, outerY),
        Offset(outerEndX, outerY),
        paint,
      );
      canvas.drawLine(
        Offset(innerStartX, innerY),
        Offset(innerEndX, innerY),
        paint,
      );

      // Corner dots only at + junctions (outer shortened implies inner too).
      if (shortenOuterStart) {
        final dotX = start.dx + 0.5 - width;
        _drawCornerDot(canvas, dotX, outerY, paint);
        _drawCornerDot(canvas, dotX, innerY, paint);
      }
      if (shortenOuterEnd) {
        final dotX = end.dx + 0.5 + width;
        _drawCornerDot(canvas, dotX, outerY, paint);
        _drawCornerDot(canvas, dotX, innerY, paint);
      }
    } else {
      // Vertical line → offset horizontally
      final outerX = start.dx + outerSign * width;
      final innerX = start.dx - outerSign * width;

      final outerStartY = shortenOuterStart
          ? start.dy + 1.0
          : start.dy - outerStartExt;
      final outerEndY = shortenOuterEnd ? end.dy : end.dy + outerEndExt;
      final innerStartY = shortenInnerStart ? start.dy + 1.0 : start.dy - 1.0;
      final innerEndY = shortenInnerEnd ? end.dy : end.dy + 1.0;

      canvas.drawLine(
        Offset(outerX, outerStartY),
        Offset(outerX, outerEndY),
        paint,
      );
      canvas.drawLine(
        Offset(innerX, innerStartY),
        Offset(innerX, innerEndY),
        paint,
      );

      // Corner dots only at + junctions.
      if (shortenOuterStart) {
        final dotY = start.dy + 0.5 - width;
        _drawCornerDot(canvas, outerX, dotY, paint);
        _drawCornerDot(canvas, innerX, dotY, paint);
      }
      if (shortenOuterEnd) {
        final dotY = end.dy + 0.5 + width;
        _drawCornerDot(canvas, outerX, dotY, paint);
        _drawCornerDot(canvas, innerX, dotY, paint);
      }
    }
  }

  /// Draws a single-pixel dot at the pixel containing ([x], [y]).
  ///
  /// In Skia with `isAntiAlias = false`, pixel (px, py) has its center at
  /// the integer coordinate (px, py). A 1px stroke from (px, py) to
  /// (px+1, py) fills exactly that one pixel. The half-pixel sub-line
  /// positions (e.g. 39.5) are floored to target the correct pixel (39).
  static void _drawCornerDot(Canvas canvas, double x, double y, Paint paint) {
    final px = x.floor().toDouble();
    final py = y.floor().toDouble();
    canvas.drawLine(Offset(px, py), Offset(px + 1.0, py), paint);
  }
}
