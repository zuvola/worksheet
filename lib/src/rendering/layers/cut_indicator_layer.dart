import 'dart:ui';

import '../../core/geometry/layout_solver.dart';
import '../../core/models/cell_range.dart';
import 'render_layer.dart';

/// Renders marching ants around cells marked for cut (Ctrl+X).
///
/// Paint order 96 — between formula references (95) and selection (100).
/// The animation is driven externally via [animationValue] (0..1), which
/// shifts the dash offset to create the marching effect.
class CutIndicatorLayer extends RenderLayer {
  /// The cell range marked for cut, or null if no cut is pending.
  CellRange? range;

  /// Animation value 0..1 for the marching ants dash offset.
  double animationValue = 0;

  /// The layout solver for computing cell bounds.
  final LayoutSolver layoutSolver;

  /// Called when this layer needs a repaint.
  final VoidCallback? onNeedsPaint;

  static const double _borderWidth = 2.0;
  static const double _dashLength = 6.0;
  static const double _gapLength = 4.0;

  CutIndicatorLayer({required this.layoutSolver, this.onNeedsPaint});

  @override
  int get order => 96;

  @override
  void markNeedsPaint() {
    onNeedsPaint?.call();
  }

  @override
  void paint(LayerPaintContext context) {
    if (!enabled || range == null) return;

    final r = range!;
    final zoom = context.zoom;
    final scrollOffset = context.scrollOffset;

    final bounds = layoutSolver.getRangeBounds(
      startRow: r.startRow,
      startColumn: r.startColumn,
      endRow: r.endRow,
      endColumn: r.endColumn,
    );

    final rect = Rect.fromLTWH(
      bounds.left * zoom - scrollOffset.dx,
      bounds.top * zoom - scrollOffset.dy,
      bounds.width * zoom,
      bounds.height * zoom,
    );

    // Clip to viewport.
    if (!rect.overlaps(Offset.zero & context.viewportSize)) return;

    _paintMarchingAnts(context.canvas, rect);
  }

  void _paintMarchingAnts(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;

    final totalDash = _dashLength + _gapLength;
    final offset = animationValue * totalDash;

    _drawDashedLine(canvas, paint, rect.topLeft, rect.topRight, offset);
    _drawDashedLine(canvas, paint, rect.topRight, rect.bottomRight, offset);
    _drawDashedLine(canvas, paint, rect.bottomRight, rect.bottomLeft, offset);
    _drawDashedLine(canvas, paint, rect.bottomLeft, rect.topLeft, offset);
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashOffset,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = (Offset(dx, dy)).distance;
    if (length == 0) return;

    final unitX = dx / length;
    final unitY = dy / length;
    final totalDash = _dashLength + _gapLength;

    double d = -dashOffset % totalDash;
    if (d < 0) d += totalDash;

    while (d < length) {
      final dashStart = d.clamp(0, length);
      final dashEnd = (d + _dashLength).clamp(0, length);
      if (dashEnd > dashStart) {
        canvas.drawLine(
          Offset(start.dx + unitX * dashStart, start.dy + unitY * dashStart),
          Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
          paint,
        );
      }
      d += totalDash;
    }
  }
}
