import 'dart:ui';

import '../../core/core.dart';
import '../../interaction/interaction.dart';
import '../painters/header_renderer.dart';
import 'render_layer.dart';

/// Layer for rendering row and column headers.
///
/// Headers are painted in a fixed position relative to the viewport,
/// with only the relevant axis scrolling (row headers scroll vertically,
/// column headers scroll horizontally).
///
/// When [freezeConfig] has frozen panes, frozen column/row headers are
/// painted at a fixed position (zero scroll offset on the frozen axis)
/// so they stay pinned alongside their frozen content cells.
class HeaderLayer extends RenderLayer {
  /// The renderer for painting headers.
  final HeaderRenderer renderer;

  /// The selection controller for highlighting headers.
  final SelectionController? selectionController;

  /// Function to get visible column range based on viewport.
  final SpanRange Function(double scrollX, double viewportWidth, double zoom)
  getVisibleColumns;

  /// Function to get visible row range based on viewport.
  final SpanRange Function(double scrollY, double viewportHeight, double zoom)
  getVisibleRows;

  /// Callback to trigger repaint when needed.
  final VoidCallback? onNeedsPaint;

  /// Freeze configuration for pinning headers alongside frozen cells.
  FreezeConfig freezeConfig;

  /// Color of the separator line at the frozen boundary in the header area.
  final Color separatorColor;

  /// Width of the separator line at the frozen boundary in the header area.
  final double separatorWidth;

  // Pre-allocated paint for frozen boundary separator lines.
  late final Paint _separatorPaint;

  /// Creates a header layer.
  HeaderLayer({
    required this.renderer,
    required this.getVisibleColumns,
    required this.getVisibleRows,
    this.selectionController,
    this.onNeedsPaint,
    this.freezeConfig = FreezeConfig.none,
    this.separatorColor = const Color(0xFF9E9E9E),
    this.separatorWidth = 2.0,
    super.enabled,
  }) {
    selectionController?.addListener(_onSelectionChanged);
    _separatorPaint = Paint()
      ..color = separatorColor
      ..strokeWidth = separatorWidth
      ..style = PaintingStyle.stroke;
  }

  @override
  int get order => 200; // Above selection layer

  void _onSelectionChanged() {
    markNeedsPaint();
  }

  @override
  void markNeedsPaint() {
    onNeedsPaint?.call();
  }

  @override
  void paint(LayerPaintContext context) {
    if (!enabled) return;

    final selectedRange = selectionController?.selectedRange;
    final zoom = context.zoom;
    final canvas = context.canvas;

    // Scale header dimensions by zoom
    final scaledRowHeaderWidth = renderer.rowHeaderWidth * zoom;
    final scaledColumnHeaderHeight = renderer.columnHeaderHeight * zoom;

    // Calculate visible ranges
    final visibleColumns = getVisibleColumns(
      context.scrollOffset.dx,
      context.viewportSize.width - scaledRowHeaderWidth,
      zoom,
    );

    final visibleRows = getVisibleRows(
      context.scrollOffset.dy,
      context.viewportSize.height - scaledColumnHeaderHeight,
      zoom,
    );

    // Save canvas state before painting headers
    canvas.save();

    // Paint column headers (at top, scrolls horizontally)
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        scaledRowHeaderWidth,
        0,
        context.viewportSize.width - scaledRowHeaderWidth,
        scaledColumnHeaderHeight,
      ),
    );
    renderer.paintColumnHeaders(
      canvas: canvas,
      viewportOffset: context.scrollOffset,
      zoom: zoom,
      visibleColumns: visibleColumns,
      selectedRange: selectedRange,
      viewportSize: context.viewportSize,
    );
    canvas.restore();

    // Paint row headers (at left, scrolls vertically)
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        0,
        scaledColumnHeaderHeight,
        scaledRowHeaderWidth,
        context.viewportSize.height - scaledColumnHeaderHeight,
      ),
    );
    renderer.paintRowHeaders(
      canvas: canvas,
      viewportOffset: context.scrollOffset,
      zoom: zoom,
      visibleRows: visibleRows,
      selectedRange: selectedRange,
      viewportSize: context.viewportSize,
    );
    canvas.restore();

    // Overpaint frozen column headers (fixed, no horizontal scroll)
    if (freezeConfig.hasFrozenColumns) {
      double frozenColsW = 0;
      for (int col = 0; col < freezeConfig.frozenColumns; col++) {
        frozenColsW += renderer.layoutSolver.getColumnWidth(col) * zoom;
      }
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          scaledRowHeaderWidth,
          0,
          frozenColsW,
          scaledColumnHeaderHeight,
        ),
      );
      renderer.paintColumnHeaders(
        canvas: canvas,
        viewportOffset: Offset(0, context.scrollOffset.dy),
        zoom: zoom,
        visibleColumns: SpanRange(0, freezeConfig.frozenColumns - 1),
        selectedRange: selectedRange,
        viewportSize: context.viewportSize,
      );
      canvas.restore();
    }

    // Overpaint frozen row headers (fixed, no vertical scroll)
    if (freezeConfig.hasFrozenRows) {
      double frozenRowsH = 0;
      for (int row = 0; row < freezeConfig.frozenRows; row++) {
        frozenRowsH += renderer.layoutSolver.getRowHeight(row) * zoom;
      }
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          0,
          scaledColumnHeaderHeight,
          scaledRowHeaderWidth,
          frozenRowsH,
        ),
      );
      renderer.paintRowHeaders(
        canvas: canvas,
        viewportOffset: Offset(context.scrollOffset.dx, 0),
        zoom: zoom,
        visibleRows: SpanRange(0, freezeConfig.frozenRows - 1),
        selectedRange: selectedRange,
        viewportSize: context.viewportSize,
      );
      canvas.restore();
    }

    // Draw frozen boundary separator lines through the header area
    if (freezeConfig.hasFrozenColumns) {
      double frozenColsW = 0;
      for (int col = 0; col < freezeConfig.frozenColumns; col++) {
        frozenColsW += renderer.layoutSolver.getColumnWidth(col) * zoom;
      }
      final x = (scaledRowHeaderWidth + frozenColsW).roundToDouble();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, scaledColumnHeaderHeight),
        _separatorPaint,
      );
    }
    if (freezeConfig.hasFrozenRows) {
      double frozenRowsH = 0;
      for (int row = 0; row < freezeConfig.frozenRows; row++) {
        frozenRowsH += renderer.layoutSolver.getRowHeight(row) * zoom;
      }
      final y = (scaledColumnHeaderHeight + frozenRowsH).roundToDouble();
      canvas.drawLine(
        Offset(0, y),
        Offset(scaledRowHeaderWidth, y),
        _separatorPaint,
      );
    }

    // Paint corner cell (intersection of row and column headers)
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, scaledRowHeaderWidth, scaledColumnHeaderHeight),
    );
    renderer.paintCornerCell(canvas, zoom: zoom);
    canvas.restore();

    // Draw header border lines (unclipped so they span full width/height)
    renderer.paintHeaderBorders(
      canvas: canvas,
      viewportSize: context.viewportSize,
      zoom: zoom,
      scrollOffset: context.scrollOffset,
    );

    // Restore canvas state
    canvas.restore();
  }

  @override
  void dispose() {
    selectionController?.removeListener(_onSelectionChanged);
  }
}
