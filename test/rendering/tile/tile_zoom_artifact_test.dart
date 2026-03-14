import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet/src/rendering/tile/tile_painter.dart';

/// Composites two adjacent tiles using the same transforms as
/// [RenderWorksheetViewport.paint], then returns pixel data.
///
/// The output image is [imageWidth] × [imageHeight] logical pixels.
/// Each tile is rendered at the given [zoom] with tile size [tileSize].
/// [devicePixelRatio] mirrors the DPR-aware snapping in the viewport.
Future<ByteData> compositeTiles({
  required TilePainter painter,
  required LayoutSolver layoutSolver,
  required double zoom,
  required TileCoordinate tile0,
  required TileCoordinate tile1,
  double tileSize = 256,
  double devicePixelRatio = 1.0,
  int imageWidth = 512,
  int imageHeight = 512,
}) async {
  // Render each tile's Picture (same as TileManager._renderTile)
  final zoomBucket = ZoomBucket.fromZoom(zoom);

  ui.Picture renderOneTile(TileCoordinate coord) {
    final bounds = coord.pixelBounds(tileWidth: tileSize, tileHeight: tileSize);
    // Compute cell range covered by the tile
    final startRow = layoutSolver.getRowAt(bounds.top).clamp(0, 999);
    final startCol = layoutSolver.getColumnAt(bounds.left).clamp(0, 99);
    final endRow = layoutSolver.getRowAt(bounds.bottom - 0.001).clamp(0, 999);
    final endCol = layoutSolver.getColumnAt(bounds.right - 0.001).clamp(0, 99);

    return painter.renderTile(
      coordinate: coord,
      bounds: bounds,
      cellRange: CellRange(startRow, startCol, endRow, endCol),
      zoomBucket: zoomBucket,
    );
  }

  final picture0 = renderOneTile(tile0);
  final picture1 = renderOneTile(tile1);

  // Composite using the exact same transform chain as
  // RenderWorksheetViewport.paint (scroll = 0 for simplicity):
  //   canvas.scale(zoom)
  //   canvas.translate(-scrollX, -scrollY)  // 0 here
  //   for each tile:
  //     canvas.save()
  //     canvas.translate(tileBounds.left, tileBounds.top)
  //     canvas.drawPicture(picture)
  //     canvas.restore()
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
  );

  // White background — any gap artifact will show the canvas background
  // which defaults to transparent black. By filling white, gaps appear as
  // transparent/dark pixels breaking the white field.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );

  canvas.scale(zoom);

  for (final entry in [(tile0, picture0), (tile1, picture1)]) {
    final bounds = entry.$1.pixelBounds(
      tileWidth: tileSize,
      tileHeight: tileSize,
    );
    // Mirror the viewport's device-pixel-aware snapping fix
    final effectiveScale = zoom * devicePixelRatio;
    final snappedLeft =
        (bounds.left * effectiveScale).floorToDouble() / effectiveScale;
    final snappedTop =
        (bounds.top * effectiveScale).floorToDouble() / effectiveScale;
    canvas.save();
    canvas.translate(snappedLeft, snappedTop);
    canvas.drawPicture(entry.$2);
    canvas.restore();
  }

  final composite = recorder.endRecording();
  final image = await composite.toImage(imageWidth, imageHeight);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  picture0.dispose();
  picture1.dispose();
  composite.dispose();
  image.dispose();

  return bytes!;
}

/// Returns the ARGB color at pixel (x, y) from RGBA byte data.
int pixelAt(ByteData bytes, int x, int y, {int width = 512}) {
  final offset = (y * width + x) * 4;
  final r = bytes.getUint8(offset);
  final g = bytes.getUint8(offset + 1);
  final b = bytes.getUint8(offset + 2);
  final a = bytes.getUint8(offset + 3);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

bool isWhite(int argb) => argb == 0xFFFFFFFF;

/// Returns true if the pixel is an artifact — not white and not a gridline.
/// Gridline color is 0xFFD4D4D4 by default.
bool isArtifact(int argb) {
  if (argb == 0xFFFFFFFF) return false; // white background
  if (argb == 0xFFD4D4D4) return false; // gridline color
  // Allow near-gridline colors from anti-aliasing blending
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  // Gridline is (212, 212, 212). Allow values within ±30 of the
  // gridline channel and with decent opacity.
  if (a > 200 && (r - g).abs() < 5 && (g - b).abs() < 5 && r > 180) {
    return false; // likely a gridline or blended gridline
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SparseWorksheetData data;
  late LayoutSolver layoutSolver;
  late TilePainter painter;

  setUp(() {
    data = SparseWorksheetData(rowCount: 1000, columnCount: 100);
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 1000, defaultSize: 24.0),
      columns: SpanList(count: 100, defaultSize: 100.0),
    );
    painter = TilePainter(
      data: data,
      layoutSolver: layoutSolver,
      showGridlines: true,
      // White background so gaps show as dark pixels
      backgroundColor: const Color(0xFFFFFFFF),
    );
  });

  tearDown(() {
    data.dispose();
  });

  group('tile boundary artifacts at non-100% zoom', () {
    // Zoom levels that produce non-integer screen positions for
    // the tile boundary at worksheet x/y = 256:
    //   0.7  → 179.2 (non-integer)
    //   0.6  → 153.6 (non-integer)
    //   0.85 → 217.6 (non-integer)
    //
    // Control zoom levels that produce integer positions:
    //   0.5  → 128.0 (integer)
    //   0.75 → 192.0 (integer)

    /// Checks pixels near the tile boundary for artifact dark lines.
    ///
    /// At the given [zoom], tile 0 ends and tile 1 starts at worksheet
    /// position [tileSize] (256 by default). The screen pixel for this
    /// boundary is `tileSize * zoom`. We check a band of pixels around
    /// that position — every pixel should be white or gridline-colored,
    /// never a dark artifact.
    void expectNoHorizontalArtifacts(
      ByteData bytes,
      double zoom, {
      double tileSize = 256,
      int imageWidth = 512,
    }) {
      final screenBoundary = tileSize * zoom;
      // Check pixels in a ±2 band around the boundary
      final startX = (screenBoundary - 2).floor().clamp(0, imageWidth - 1);
      final endX = (screenBoundary + 2).ceil().clamp(0, imageWidth - 1);

      var artifactCount = 0;
      for (var x = startX; x <= endX; x++) {
        // Sample multiple rows to get a clear picture
        for (var y = 5; y < 200; y += 10) {
          final argb = pixelAt(bytes, x, y, width: imageWidth);
          if (isArtifact(argb)) {
            artifactCount++;
          }
        }
      }

      expect(
        artifactCount,
        equals(0),
        reason:
            'At zoom $zoom, found $artifactCount artifact pixels near '
            'horizontal tile boundary at screen x=${screenBoundary.toStringAsFixed(1)}',
      );
    }

    void expectNoVerticalArtifacts(
      ByteData bytes,
      double zoom, {
      double tileSize = 256,
      int imageWidth = 512,
    }) {
      final screenBoundary = tileSize * zoom;
      final startY = (screenBoundary - 2).floor().clamp(0, imageWidth - 1);
      final endY = (screenBoundary + 2).ceil().clamp(0, imageWidth - 1);

      var artifactCount = 0;
      for (var y = startY; y <= endY; y++) {
        for (var x = 5; x < 200; x += 10) {
          final argb = pixelAt(bytes, x, y, width: imageWidth);
          if (isArtifact(argb)) {
            artifactCount++;
          }
        }
      }

      expect(
        artifactCount,
        equals(0),
        reason:
            'At zoom $zoom, found $artifactCount artifact pixels near '
            'vertical tile boundary at screen y=${screenBoundary.toStringAsFixed(1)}',
      );
    }

    group('horizontal tile boundary (tiles side by side)', () {
      test('zoom 0.5 — integer boundary (control)', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.5,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 0.5);
      });

      test('zoom 0.7 — non-integer boundary at 179.2px', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.7,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 0.7);
      });

      test('zoom 0.75 — integer boundary (control)', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.75,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 0.75);
      });

      test('zoom 0.6 — non-integer boundary at 153.6px', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.6,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 0.6);
      });

      test('zoom 0.85 — non-integer boundary at 217.6px', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.85,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 0.85);
      });
    });

    group('fractional DPR (Chrome browser zoom)', () {
      test('zoom 1.0 with DPR 1.1 — simulates 110% browser zoom', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 1.0,
          devicePixelRatio: 1.1,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 1.0);
      });

      test(
        'zoom 0.7 with DPR 1.25 — fractional zoom + fractional DPR',
        () async {
          final bytes = await compositeTiles(
            painter: painter,
            layoutSolver: layoutSolver,
            zoom: 0.7,
            devicePixelRatio: 1.25,
            tile0: TileCoordinate(0, 0),
            tile1: TileCoordinate(0, 1),
          );
          expectNoHorizontalArtifacts(bytes, 0.7);
        },
      );

      test('zoom 0.85 with DPR 1.5 — Retina-like fractional', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.85,
          devicePixelRatio: 1.5,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(0, 1),
        );
        expectNoHorizontalArtifacts(bytes, 0.85);
      });
    });

    group('vertical tile boundary (tiles stacked)', () {
      test('zoom 0.5 — integer boundary (control)', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.5,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(1, 0),
        );
        expectNoVerticalArtifacts(bytes, 0.5);
      });

      test('zoom 0.7 — non-integer boundary at 179.2px', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.7,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(1, 0),
        );
        expectNoVerticalArtifacts(bytes, 0.7);
      });

      test('zoom 0.6 — non-integer boundary at 153.6px', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.6,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(1, 0),
        );
        expectNoVerticalArtifacts(bytes, 0.6);
      });

      test('zoom 0.85 — non-integer boundary at 217.6px', () async {
        final bytes = await compositeTiles(
          painter: painter,
          layoutSolver: layoutSolver,
          zoom: 0.85,
          tile0: TileCoordinate(0, 0),
          tile1: TileCoordinate(1, 0),
        );
        expectNoVerticalArtifacts(bytes, 0.85);
      });
    });
  });
}
