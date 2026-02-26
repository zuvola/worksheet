import 'package:flutter/painting.dart' hide BorderStyle;

import '../../core/core.dart';
import '../../widgets/worksheet_theme.dart';
import '../painters/cell_border_renderer.dart';
import 'render_layer.dart';

/// Callback when the layer needs to be repainted.
typedef FrozenLayerNeedsPaintCallback = void Function();

/// Renders frozen (pinned) rows and columns.
///
/// Frozen panes are split into three regions:
/// 1. Corner: Frozen rows AND columns (fixed position)
/// 2. Frozen rows: Top strip (scrolls horizontally, fixed vertically)
/// 3. Frozen columns: Left strip (fixed horizontally, scrolls vertically)
///
/// This layer is painted on top of the content layer to ensure frozen
/// cells obscure scrolling content beneath them.
class FrozenLayer extends RenderLayer {
  FreezeConfig _freezeConfig;
  final WorksheetData data;
  final LayoutSolver layoutSolver;
  final FrozenLayerNeedsPaintCallback? onNeedsPaint;

  /// Merged cell registry for merge-aware rendering.
  MergedCellRegistry? mergedCells;

  // Style configuration
  final Color backgroundColor;
  final Color gridlineColor;
  final Color separatorColor;
  final double separatorWidth;
  final Color defaultTextColor;
  final double defaultFontSize;
  final String defaultFontFamily;
  final double cellPadding;

  /// Device pixel ratio for crisp 1-physical-pixel lines on Retina displays.
  final double? devicePixelRatio;

  // Pre-allocated paints
  late final Paint _backgroundPaint;
  late final Paint _gridlinePaint;
  late final Paint _separatorPaint;
  late final Paint _cellBackgroundPaint;
  late final Paint _borderPaint;

  /// Creates a frozen layer.
  FrozenLayer({
    required FreezeConfig freezeConfig,
    required this.data,
    required this.layoutSolver,
    this.onNeedsPaint,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.gridlineColor = const Color(0xFFD4D4D4),
    this.separatorColor = const Color(0xFF9E9E9E),
    this.separatorWidth = 2.0,
    this.defaultTextColor = const Color(0xFF000000),
    this.defaultFontSize = 14.0,
    this.defaultFontFamily = CellStyle.defaultFontFamily,
    this.cellPadding = 4.0,
    this.devicePixelRatio,
  }) : _freezeConfig = freezeConfig,
       super(enabled: freezeConfig.hasFrozenPanes) {
    _initPaints();
  }

  void _initPaints() {
    _backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    _gridlinePaint = Paint()
      ..color = gridlineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;

    _separatorPaint = Paint()
      ..color = separatorColor
      ..strokeWidth = separatorWidth
      ..style = PaintingStyle.stroke;

    _cellBackgroundPaint = Paint()..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;
  }

  /// Frozen layers paint on top of content (order 4).
  @override
  int get order => 4;

  /// The current freeze configuration.
  FreezeConfig get freezeConfig => _freezeConfig;

  /// Updates the freeze configuration.
  void updateFreezeConfig(FreezeConfig config) {
    if (_freezeConfig == config) return;
    _freezeConfig = config;
    enabled = config.hasFrozenPanes;
    markNeedsPaint();
  }

  /// The height of frozen rows in pixels.
  double get frozenRowsHeight {
    if (!_freezeConfig.hasFrozenRows) return 0.0;
    double height = 0.0;
    for (int row = 0; row < _freezeConfig.frozenRows; row++) {
      height += layoutSolver.getRowHeight(row);
    }
    return height;
  }

  /// The width of frozen columns in pixels.
  double get frozenColumnsWidth {
    if (!_freezeConfig.hasFrozenColumns) return 0.0;
    double width = 0.0;
    for (int col = 0; col < _freezeConfig.frozenColumns; col++) {
      width += layoutSolver.getColumnWidth(col);
    }
    return width;
  }

  @override
  void paint(LayerPaintContext context) {
    if (!enabled) return;

    final canvas = context.canvas;
    final viewportSize = context.viewportSize;
    final scrollOffset = context.scrollOffset;
    final zoom = context.zoom;

    // Calculate frozen dimensions at current zoom
    final frozenRowsH = frozenRowsHeight * zoom;
    final frozenColsW = frozenColumnsWidth * zoom;

    // Paint corner region (if both rows and columns are frozen)
    if (_freezeConfig.hasFrozenRows && _freezeConfig.hasFrozenColumns) {
      _paintCorner(canvas, Rect.fromLTWH(0, 0, frozenColsW, frozenRowsH), zoom);
    }

    // Paint frozen rows (top strip, excluding corner)
    if (_freezeConfig.hasFrozenRows) {
      final rowsLeft = _freezeConfig.hasFrozenColumns ? frozenColsW : 0.0;
      _paintFrozenRows(
        canvas,
        Rect.fromLTWH(rowsLeft, 0, viewportSize.width - rowsLeft, frozenRowsH),
        scrollOffset.dx,
        zoom,
      );
    }

    // Paint frozen columns (left strip, excluding corner)
    if (_freezeConfig.hasFrozenColumns) {
      final colsTop = _freezeConfig.hasFrozenRows ? frozenRowsH : 0.0;
      _paintFrozenColumns(
        canvas,
        Rect.fromLTWH(0, colsTop, frozenColsW, viewportSize.height - colsTop),
        scrollOffset.dy,
        zoom,
      );
    }

    // Draw separator lines
    _paintSeparators(canvas, viewportSize, frozenRowsH, frozenColsW);
  }

  void _paintCorner(Canvas canvas, Rect bounds, double zoom) {
    canvas.save();
    canvas.clipRect(bounds);

    // Fill background
    canvas.drawRect(bounds, _backgroundPaint);

    // Paint cells in corner region
    final cornerRendered = <CellCoordinate>{};
    for (int row = 0; row < _freezeConfig.frozenRows; row++) {
      for (int col = 0; col < _freezeConfig.frozenColumns; col++) {
        final coord = CellCoordinate(row, col);

        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;
        if (region != null) {
          if (cornerRendered.contains(renderCoord)) continue;
          cornerRendered.add(renderCoord);
        }

        final cellBounds = layoutSolver.getCellBounds(renderCoord);
        final scaledBounds = Rect.fromLTWH(
          cellBounds.left * zoom,
          cellBounds.top * zoom,
          cellBounds.width * zoom,
          cellBounds.height * zoom,
        );
        _paintCell(canvas, renderCoord, scaledBounds, zoom);
      }
    }

    // Paint gridlines
    _paintGridlines(
      canvas,
      bounds,
      0,
      _freezeConfig.frozenRows - 1,
      0,
      _freezeConfig.frozenColumns - 1,
      0,
      0,
      zoom,
    );

    // Paint borders on top of all cell backgrounds (fixes z-order)
    if (zoom >= 0.4) {
      CellBorderRenderer.renderBorders(
        canvas: canvas,
        borderPaint: _borderPaint,
        data: data,
        mergedCells: mergedCells,
        startRow: 0,
        endRow: _freezeConfig.frozenRows - 1,
        startCol: 0,
        endCol: _freezeConfig.frozenColumns - 1,
        maxRow: layoutSolver.rowCount - 1,
        maxCol: layoutSolver.columnCount - 1,
        getBounds: (coord) {
          final cellBounds = layoutSolver.getCellBounds(coord);
          return Rect.fromLTWH(
            cellBounds.left * zoom,
            cellBounds.top * zoom,
            cellBounds.width * zoom,
            cellBounds.height * zoom,
          );
        },
        widthScale: 1.0,
      );
    }

    canvas.restore();
  }

  void _paintFrozenRows(
    Canvas canvas,
    Rect bounds,
    double scrollX,
    double zoom,
  ) {
    canvas.save();
    canvas.clipRect(bounds);

    // Fill background
    canvas.drawRect(bounds, _backgroundPaint);

    // Calculate visible column range
    final visibleColStart = layoutSolver.getColumnAt(scrollX);
    final visibleColEnd = layoutSolver.getColumnAt(
      scrollX + bounds.width / zoom,
    );

    final startCol = _freezeConfig.hasFrozenColumns
        ? _freezeConfig.frozenColumns
        : visibleColStart;
    final endCol = (visibleColEnd + 1).clamp(0, layoutSolver.columnCount - 1);

    // Paint cells
    // Cell coordinates are absolute — don't add bounds.left offset.
    // The clip rect handles hiding content that overlaps the frozen columns.
    final frozenRowsRendered = <CellCoordinate>{};
    for (int row = 0; row < _freezeConfig.frozenRows; row++) {
      for (int col = startCol; col <= endCol; col++) {
        final coord = CellCoordinate(row, col);

        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;
        if (region != null) {
          if (frozenRowsRendered.contains(renderCoord)) continue;
          frozenRowsRendered.add(renderCoord);
        }

        final cellBounds = layoutSolver.getCellBounds(renderCoord);
        final scaledBounds = Rect.fromLTWH(
          (cellBounds.left - scrollX) * zoom,
          cellBounds.top * zoom,
          cellBounds.width * zoom,
          cellBounds.height * zoom,
        );

        if (scaledBounds.right > bounds.left &&
            scaledBounds.left < bounds.right) {
          _paintCell(canvas, renderCoord, scaledBounds, zoom);
        }
      }
    }

    // Paint gridlines
    _paintGridlines(
      canvas,
      bounds,
      0,
      _freezeConfig.frozenRows - 1,
      startCol,
      endCol,
      scrollX,
      0,
      zoom,
    );

    // Paint borders on top of all cell backgrounds (fixes z-order)
    if (zoom >= 0.4) {
      final frozenRowsScrollX = scrollX;
      CellBorderRenderer.renderBorders(
        canvas: canvas,
        borderPaint: _borderPaint,
        data: data,
        mergedCells: mergedCells,
        startRow: 0,
        endRow: _freezeConfig.frozenRows - 1,
        startCol: startCol,
        endCol: endCol,
        maxRow: layoutSolver.rowCount - 1,
        maxCol: layoutSolver.columnCount - 1,
        getBounds: (coord) {
          final cellBounds = layoutSolver.getCellBounds(coord);
          return Rect.fromLTWH(
            (cellBounds.left - frozenRowsScrollX) * zoom,
            cellBounds.top * zoom,
            cellBounds.width * zoom,
            cellBounds.height * zoom,
          );
        },
        widthScale: 1.0,
      );
    }

    canvas.restore();
  }

  void _paintFrozenColumns(
    Canvas canvas,
    Rect bounds,
    double scrollY,
    double zoom,
  ) {
    canvas.save();
    canvas.clipRect(bounds);

    // Fill background
    canvas.drawRect(bounds, _backgroundPaint);

    // Calculate visible row range
    final visibleRowStart = layoutSolver.getRowAt(scrollY);
    final visibleRowEnd = layoutSolver.getRowAt(scrollY + bounds.height / zoom);

    final startRow = _freezeConfig.hasFrozenRows
        ? _freezeConfig.frozenRows
        : visibleRowStart;
    final endRow = (visibleRowEnd + 1).clamp(0, layoutSolver.rowCount - 1);

    // Paint cells
    // Cell coordinates are absolute — don't add bounds.top offset.
    // The clip rect handles hiding content that overlaps the frozen rows.
    final frozenColsRendered = <CellCoordinate>{};
    for (int row = startRow; row <= endRow; row++) {
      for (int col = 0; col < _freezeConfig.frozenColumns; col++) {
        final coord = CellCoordinate(row, col);

        final region = mergedCells?.getRegion(coord);
        final renderCoord = region?.anchor ?? coord;
        if (region != null) {
          if (frozenColsRendered.contains(renderCoord)) continue;
          frozenColsRendered.add(renderCoord);
        }

        final cellBounds = layoutSolver.getCellBounds(renderCoord);
        final scaledBounds = Rect.fromLTWH(
          cellBounds.left * zoom,
          (cellBounds.top - scrollY) * zoom,
          cellBounds.width * zoom,
          cellBounds.height * zoom,
        );

        if (scaledBounds.bottom > bounds.top &&
            scaledBounds.top < bounds.bottom) {
          _paintCell(canvas, renderCoord, scaledBounds, zoom);
        }
      }
    }

    // Paint gridlines
    _paintGridlines(
      canvas,
      bounds,
      startRow,
      endRow,
      0,
      _freezeConfig.frozenColumns - 1,
      0,
      scrollY,
      zoom,
    );

    // Paint borders on top of all cell backgrounds (fixes z-order)
    if (zoom >= 0.4) {
      final frozenColsScrollY = scrollY;
      CellBorderRenderer.renderBorders(
        canvas: canvas,
        borderPaint: _borderPaint,
        data: data,
        mergedCells: mergedCells,
        startRow: startRow,
        endRow: endRow,
        startCol: 0,
        endCol: _freezeConfig.frozenColumns - 1,
        maxRow: layoutSolver.rowCount - 1,
        maxCol: layoutSolver.columnCount - 1,
        getBounds: (coord) {
          final cellBounds = layoutSolver.getCellBounds(coord);
          return Rect.fromLTWH(
            cellBounds.left * zoom,
            (cellBounds.top - frozenColsScrollY) * zoom,
            cellBounds.width * zoom,
            cellBounds.height * zoom,
          );
        },
        widthScale: 1.0,
      );
    }

    canvas.restore();
  }

  void _paintCell(
    Canvas canvas,
    CellCoordinate coord,
    Rect bounds,
    double zoom,
  ) {
    // Paint background
    final style = data.getStyle(coord);
    final bgColor = style?.backgroundColor;
    if (bgColor != null) {
      _cellBackgroundPaint.color = bgColor;
      canvas.drawRect(bounds, _cellBackgroundPaint);
    }

    // Paint content
    final value = data.getCell(coord);
    if (value != null && zoom >= 0.25) {
      final format = data.getFormat(coord);
      _paintCellContent(
        canvas,
        bounds,
        value,
        style,
        zoom,
        format,
        coord: coord,
      );
    }

    // Borders are rendered after ALL cells in _paintCorner/_paintFrozenRows/
    // _paintFrozenColumns to fix z-order (a cell's borders must not be hidden
    // by the next cell's background).
  }

  void _paintCellContent(
    Canvas canvas,
    Rect bounds,
    CellValue value,
    CellStyle? style,
    double zoom,
    CellFormat? format, {
    CellCoordinate? coord,
    Rect? regionClipRect,
  }) {
    final mergedStyle = CellStyle.defaultStyle.merge(style);
    final padding = cellPadding * zoom;
    final availableWidth = bounds.width - (padding * 2);
    final wrapText = mergedStyle.wrapText == true;
    final CellFormatResult? formatResult;
    final String text;
    if (format != null) {
      formatResult = format.formatRich(value, availableWidth: availableWidth);
      text = formatResult.text;
    } else {
      formatResult = null;
      text = value.displayValue;
    }

    // Base style from theme defaults — text appearance comes from rich text spans
    final Color baseTextColor;
    if (formatResult?.color != null) {
      baseTextColor = formatResult!.color!;
    } else if (value.isError) {
      baseTextColor = const Color(0xFFCC0000);
    } else {
      baseTextColor = defaultTextColor;
    }
    final baseTextStyle = TextStyle(
      color: baseTextColor,
      fontSize: defaultFontSize * zoom,
      fontFamily: defaultFontFamily,
      package: WorksheetThemeData.resolveFontPackage(defaultFontFamily),
    );

    // Use rich text spans when available for inline styling
    final TextSpan textSpan;
    final richText = coord != null ? data.getRichText(coord) : null;
    if (richText != null && richText.isNotEmpty) {
      // Scale child span font sizes by zoom to match frozen layer rendering
      final scaledChildren = richText.map((span) {
        final spanStyle = span.style;
        if (spanStyle != null && spanStyle.fontSize != null) {
          return TextSpan(
            text: span.text,
            style: spanStyle.copyWith(fontSize: spanStyle.fontSize! * zoom),
          );
        }
        return span;
      }).toList();
      textSpan = TextSpan(style: baseTextStyle, children: scaledChildren);
    } else {
      textSpan = TextSpan(text: text, style: baseTextStyle);
    }

    // For non-wrap cells, attempt spillover before falling back to ellipsis.
    if (!wrapText) {
      final unconstrained = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: _toTextAlign(
          mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type),
        ),
        maxLines: 1,
      )..layout();
      final textWidth = unconstrained.width;

      if (textWidth <= availableWidth || availableWidth <= 0) {
        // Text fits — paint normally.
        final offset = _calculateTextOffset(
          bounds,
          unconstrained,
          mergedStyle,
          padding,
          value,
        );
        canvas.save();
        canvas.clipRect(bounds);
        unconstrained.paint(canvas, offset);
        canvas.restore();
        unconstrained.dispose();
        return;
      }

      // Text overflows — compute spillover using worksheet coordinates.
      final alignment =
          mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type);
      final maxCol = layoutSolver.columnCount - 1;
      // Convert zoomed text width to worksheet coordinates for the calculator.
      final textWidthWs = textWidth / zoom;
      final cellWidthWs = bounds.width / zoom;

      final extent = SpilloverCalculator.compute(
        row: coord?.row ?? 0,
        column: coord?.column ?? 0,
        textWidth: textWidthWs,
        cellWidth: cellWidthWs,
        cellPadding: cellPadding,
        alignment: alignment,
        valueType: value.type,
        wrapText: false,
        data: data,
        layoutSolver: layoutSolver,
        mergedCells: mergedCells,
        maxColumn: maxCol,
      );

      if (extent.showHashFill) {
        unconstrained.dispose();
        final hashPainter = TextPainter(
          text: TextSpan(text: '######', style: baseTextStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0.0);
        final offset = _calculateTextOffset(
          bounds,
          hashPainter,
          mergedStyle,
          padding,
          value,
        );
        canvas.save();
        canvas.clipRect(bounds);
        hashPainter.paint(canvas, offset);
        canvas.restore();
        hashPainter.dispose();
        return;
      }

      if (extent.hasSpillover) {
        // Compute spill bounds in screen coordinates.
        // We need to figure out where the spill columns are on screen.
        // bounds is already in screen coords for this cell; we derive the
        // spill bounds relative to bounds by using worksheet column positions.
        final cellWsLeft = layoutSolver.getColumnLeft(coord?.column ?? 0);
        final spillWsLeft = layoutSolver.getColumnLeft(extent.startColumn);
        final spillScreenLeft = bounds.left + (spillWsLeft - cellWsLeft) * zoom;
        final spillScreenWidth = extent.totalWidth * zoom;

        final spillBounds = Rect.fromLTWH(
          spillScreenLeft,
          bounds.top,
          spillScreenWidth,
          bounds.height,
        );

        // Clip to the frozen region clip rect if provided, otherwise spill bounds.
        final clipRect = regionClipRect != null
            ? spillBounds.intersect(regionClipRect)
            : spillBounds;

        unconstrained.dispose();
        final spillPadding = cellPadding * zoom;
        final spillPainter =
            TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
              textAlign: _toTextAlign(alignment),
              maxLines: 1,
            )..layout(
              minWidth: spillScreenWidth - 2 * spillPadding,
              maxWidth: spillScreenWidth - 2 * spillPadding,
            );
        final offset = _calculateTextOffset(
          spillBounds,
          spillPainter,
          mergedStyle,
          padding,
          value,
        );
        canvas.save();
        canvas.clipRect(clipRect);
        spillPainter.paint(canvas, offset);
        canvas.restore();
        spillPainter.dispose();
        return;
      }

      // Blocked — fall through to ellipsis rendering.
      unconstrained.dispose();
    }

    // Wrapped text or blocked non-wrap: render with ellipsis / wrapping.
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: _toTextAlign(
        mergedStyle.textAlignment ?? CellStyle.implicitAlignment(value.type),
      ),
      maxLines: wrapText ? null : 1,
      ellipsis: wrapText ? null : '\u2026',
    );

    final layoutWidth = availableWidth > 0 ? availableWidth : 0.0;
    textPainter.layout(
      minWidth: wrapText ? layoutWidth : 0,
      maxWidth: layoutWidth,
    );

    final offset = _calculateTextOffset(
      bounds,
      textPainter,
      mergedStyle,
      padding,
      value,
    );

    canvas.save();
    canvas.clipRect(bounds);
    textPainter.paint(canvas, offset);
    canvas.restore();

    textPainter.dispose();
  }

  Offset _calculateTextOffset(
    Rect bounds,
    TextPainter textPainter,
    CellStyle style,
    double padding,
    CellValue value,
  ) {
    double dx;
    double dy;

    // For wrapped text, TextPainter handles per-line alignment via textAlign,
    // so always position at left + padding.
    if (style.wrapText == true) {
      dx = bounds.left + padding;
    } else {
      switch (style.textAlignment ?? CellStyle.implicitAlignment(value.type)) {
        case CellTextAlignment.left:
          dx = bounds.left + padding;
          break;
        case CellTextAlignment.center:
          dx = bounds.left + (bounds.width - textPainter.width) / 2;
          break;
        case CellTextAlignment.right:
          dx = bounds.right - padding - textPainter.width;
          break;
      }
    }

    switch (style.verticalAlignment ?? CellVerticalAlignment.middle) {
      case CellVerticalAlignment.top:
        dy = bounds.top + padding;
        break;
      case CellVerticalAlignment.middle:
        dy = bounds.top + (bounds.height - textPainter.height) / 2;
        break;
      case CellVerticalAlignment.bottom:
        dy = bounds.bottom - padding - textPainter.height;
        break;
    }

    return Offset(dx, dy);
  }

  void _paintGridlines(
    Canvas canvas,
    Rect bounds,
    int startRow,
    int endRow,
    int startCol,
    int endCol,
    double scrollX,
    double scrollY,
    double zoom, {
    double offsetX = 0,
    double offsetY = 0,
  }) {
    final path = Path();

    // Collect merge regions intersecting the visible range for gap suppression.
    final cellRange = CellRange(startRow, startCol, endRow, endCol);
    final mergeRegions = mergedCells != null && mergedCells!.regionCount > 0
        ? mergedCells!.regionsInRange(cellRange).toList()
        : const <MergeRegion>[];

    // Vertical gridlines
    for (int col = startCol; col <= endCol + 1; col++) {
      final x =
          ((layoutSolver.getColumnLeft(col) - scrollX) * zoom + offsetX)
              .roundToDouble() +
          0.5;
      if (x < bounds.left || x > bounds.right) continue;

      // Find merge regions whose interior crosses this vertical line.
      final gaps = <MergeRegion>[];
      for (final region in mergeRegions) {
        final r = region.range;
        if (r.startColumn < col && r.endColumn >= col) {
          gaps.add(region);
        }
      }

      if (gaps.isEmpty) {
        path.moveTo(x, bounds.top);
        path.lineTo(x, bounds.bottom);
      } else {
        gaps.sort((a, b) => a.range.startRow.compareTo(b.range.startRow));
        var currentY = bounds.top;
        for (final gap in gaps) {
          final gapTop =
              ((layoutSolver.getRowTop(gap.range.startRow) - scrollY) * zoom +
                      offsetY)
                  .roundToDouble();
          final gapBottom =
              ((layoutSolver.getRowTop(gap.range.endRow + 1) - scrollY) * zoom +
                      offsetY)
                  .roundToDouble();
          if (gapTop > currentY) {
            path.moveTo(x, currentY);
            path.lineTo(x, gapTop);
          }
          if (gapBottom > currentY) currentY = gapBottom;
        }
        if (currentY < bounds.bottom) {
          path.moveTo(x, currentY);
          path.lineTo(x, bounds.bottom);
        }
      }
    }

    // Horizontal gridlines
    for (int row = startRow; row <= endRow + 1; row++) {
      final y =
          ((layoutSolver.getRowTop(row) - scrollY) * zoom + offsetY)
              .roundToDouble() +
          0.5;
      if (y < bounds.top || y > bounds.bottom) continue;

      // Find merge regions whose interior crosses this horizontal line.
      final gaps = <MergeRegion>[];
      for (final region in mergeRegions) {
        final r = region.range;
        if (r.startRow < row && r.endRow >= row) {
          gaps.add(region);
        }
      }

      if (gaps.isEmpty) {
        path.moveTo(bounds.left, y);
        path.lineTo(bounds.right, y);
      } else {
        gaps.sort((a, b) => a.range.startColumn.compareTo(b.range.startColumn));
        var currentX = bounds.left;
        for (final gap in gaps) {
          final gapLeft =
              ((layoutSolver.getColumnLeft(gap.range.startColumn) - scrollX) *
                          zoom +
                      offsetX)
                  .roundToDouble();
          final gapRight =
              ((layoutSolver.getColumnLeft(gap.range.endColumn + 1) - scrollX) *
                          zoom +
                      offsetX)
                  .roundToDouble();
          if (gapLeft > currentX) {
            path.moveTo(currentX, y);
            path.lineTo(gapLeft, y);
          }
          if (gapRight > currentX) currentX = gapRight;
        }
        if (currentX < bounds.right) {
          path.moveTo(currentX, y);
          path.lineTo(bounds.right, y);
        }
      }
    }

    canvas.drawPath(path, _gridlinePaint);
  }

  void _paintSeparators(
    Canvas canvas,
    Size viewportSize,
    double frozenRowsH,
    double frozenColsW,
  ) {
    // Horizontal separator below frozen rows
    if (_freezeConfig.hasFrozenRows) {
      final y = frozenRowsH.roundToDouble();
      canvas.drawLine(
        Offset(0, y),
        Offset(viewportSize.width, y),
        _separatorPaint,
      );
    }

    // Vertical separator to the right of frozen columns
    if (_freezeConfig.hasFrozenColumns) {
      final x = frozenColsW.roundToDouble();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, viewportSize.height),
        _separatorPaint,
      );
    }
  }

  static TextAlign _toTextAlign(CellTextAlignment alignment) {
    switch (alignment) {
      case CellTextAlignment.left:
        return TextAlign.left;
      case CellTextAlignment.center:
        return TextAlign.center;
      case CellTextAlignment.right:
        return TextAlign.right;
    }
  }

  @override
  void markNeedsPaint() {
    onNeedsPaint?.call();
  }
}
