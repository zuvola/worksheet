import 'dart:ui';

import '../../core/formula/formula_tokenizer.dart';
import '../../core/geometry/layout_solver.dart';
import 'render_layer.dart';

/// Renders colored borders on cells referenced by the formula being edited,
/// with animated marching ants on the active reference.
///
/// Paint order 95 — below the [SelectionLayer] at 100, above content tiles.
class FormulaReferenceLayer extends RenderLayer {
  /// The parsed reference tokens from the current formula.
  List<FormulaToken> references = [];

  /// The index of the active reference (being manipulated), or -1.
  int activeIndex = -1;

  /// Animation value 0..1 for the marching ants dash offset.
  double animationValue = 0;

  /// The layout solver for computing cell bounds.
  final LayoutSolver layoutSolver;

  /// Called when this layer needs a repaint.
  final VoidCallback? onNeedsPaint;

  static const double _borderWidth = 2.0;
  static const double _dashLength = 6.0;
  static const double _gapLength = 4.0;

  FormulaReferenceLayer({
    required this.layoutSolver,
    this.onNeedsPaint,
  });

  @override
  int get order => 95;

  @override
  void markNeedsPaint() {
    onNeedsPaint?.call();
  }

  @override
  void paint(LayerPaintContext context) {
    if (!enabled || references.isEmpty) return;

    final canvas = context.canvas;
    final scrollOffset = context.scrollOffset;
    final zoom = context.zoom;

    for (int i = 0; i < references.length; i++) {
      final token = references[i];
      final rect = _getTokenBounds(token, zoom, scrollOffset);
      if (rect == null) continue;

      // Clip to viewport.
      if (!rect.overlaps(Offset.zero & context.viewportSize)) continue;

      if (i == activeIndex) {
        _paintMarchingAnts(canvas, rect, token.color);
      } else {
        _paintBorder(canvas, rect, token.color);
      }
    }
  }

  Rect? _getTokenBounds(FormulaToken token, double zoom, Offset scrollOffset) {
    final Rect bounds;
    if (token.range != null) {
      final r = token.range!;
      bounds = layoutSolver.getRangeBounds(
        startRow: r.startRow,
        startColumn: r.startColumn,
        endRow: r.endRow,
        endColumn: r.endColumn,
      );
    } else {
      bounds = layoutSolver.getCellBounds(token.cell);
    }

    return Rect.fromLTWH(
      bounds.left * zoom - scrollOffset.dx,
      bounds.top * zoom - scrollOffset.dy,
      bounds.width * zoom,
      bounds.height * zoom,
    );
  }

  void _paintBorder(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;
    canvas.drawRect(rect, paint);
  }

  void _paintMarchingAnts(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;

    final totalDash = _dashLength + _gapLength;
    final offset = animationValue * totalDash;

    _drawDashedLine(
      canvas, paint, rect.topLeft, rect.topRight, offset,
    );
    _drawDashedLine(
      canvas, paint, rect.topRight, rect.bottomRight, offset,
    );
    _drawDashedLine(
      canvas, paint, rect.bottomRight, rect.bottomLeft, offset,
    );
    _drawDashedLine(
      canvas, paint, rect.bottomLeft, rect.topLeft, offset,
    );
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
