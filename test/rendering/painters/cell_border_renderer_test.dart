import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/rendering/painters/cell_border_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Renders borders for [data] onto a 100x100 canvas and returns pixel data.
  ///
  /// Uses a 5x5 grid with 20px cells (rows height 20, cols width 20).
  /// Cell (r,c) occupies x=[c*20..(c+1)*20], y=[r*20..(r+1)*20].
  Future<ByteData> renderBorders(
    SparseWorksheetData data, {
    int imageWidth = 100,
    int imageHeight = 100,
  }) async {
    final layoutSolver = LayoutSolver(
      rows: SpanList(count: 5, defaultSize: 20.0),
      columns: SpanList(count: 5, defaultSize: 20.0),
    );
    layoutSolver.mergedCells = data.mergedCells;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
    );

    // Fill white background so we can detect colored border pixels
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;

    CellBorderRenderer.renderBorders(
      canvas: canvas,
      borderPaint: borderPaint,
      data: data,
      mergedCells: data.mergedCells,
      startRow: 0,
      endRow: 4,
      startCol: 0,
      endCol: 4,
      maxRow: 4,
      maxCol: 4,
      getBounds: (coord) => layoutSolver.getCellBounds(coord),
      widthScale: 1.0,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(imageWidth, imageHeight);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    picture.dispose();
    image.dispose();
    return byteData!;
  }

  /// Returns the ARGB color at pixel (x, y) from RGBA byte data.
  int pixelAt(ByteData bytes, int x, int y, {int width = 100}) {
    final offset = (y * width + x) * 4;
    final r = bytes.getUint8(offset);
    final g = bytes.getUint8(offset + 1);
    final b = bytes.getUint8(offset + 2);
    final a = bytes.getUint8(offset + 3);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  bool isWhite(int argb) {
    return argb == 0xFFFFFFFF;
  }

  bool isNonWhite(int argb) {
    return argb != 0xFFFFFFFF;
  }

  bool isColor(int argb, Color color) {
    final a = (color.a * 255.0).round().clamp(0, 255);
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return argb == ((a << 24) | (r << 16) | (g << 8) | b);
  }

  group('CellBorderRenderer', () {
    late SparseWorksheetData data;

    setUp(() {
      data = SparseWorksheetData(rowCount: 5, columnCount: 5);
    });

    tearDown(() {
      data.dispose();
    });

    group('basic edge drawing', () {
      test('single cell solid border on all 4 sides draws pixels at edges',
          () async {
        data.setStyle(
          const CellCoordinate(1, 1),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(
              color: Color(0xFF000000),
              lineStyle: BorderLineStyle.solid,
            )),
          ),
        );

        final pixels = await renderBorders(data);

        // Cell (1,1) has bounds: left=20, top=20, right=40, bottom=40
        // Top border: y ~ 20.5 → drawn at y=20 (after rounding)
        // Bottom border: y ~ 40.5 → drawn at y=40
        // Left border: x ~ 20.5 → drawn at x=20
        // Right border: x ~ 40.5 → drawn at x=40

        // Top edge: pixel at (30, 20) should be non-white (mid-top edge)
        expect(isNonWhite(pixelAt(pixels, 30, 20)), isTrue,
            reason: 'Top border should have pixels at y=20');

        // Bottom edge: pixel at (30, 40) should be non-white
        expect(isNonWhite(pixelAt(pixels, 30, 40)), isTrue,
            reason: 'Bottom border should have pixels at y=40');

        // Left edge: pixel at (20, 30) should be non-white
        expect(isNonWhite(pixelAt(pixels, 20, 30)), isTrue,
            reason: 'Left border should have pixels at x=20');

        // Right edge: pixel at (40, 30) should be non-white
        expect(isNonWhite(pixelAt(pixels, 40, 30)), isTrue,
            reason: 'Right border should have pixels at x=40');

        // Interior should be white
        expect(isWhite(pixelAt(pixels, 30, 30)), isTrue,
            reason: 'Interior of cell should remain white');

        // Exterior should be white
        expect(isWhite(pixelAt(pixels, 10, 10)), isTrue,
            reason: 'Outside cell should remain white');
      });

      test('cell at row=0, col=0 renders borders without crash', () async {
        data.setStyle(
          const CellCoordinate(0, 0),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(
              color: Color(0xFF000000),
              lineStyle: BorderLineStyle.solid,
            )),
          ),
        );

        final pixels = await renderBorders(data);

        // Top border: y ~ 0.5 → drawn at y=0 or y=1
        // Left border: x ~ 0.5 → drawn at x=0 or x=1
        // Check that a pixel near the top-left is drawn
        final topMid = pixelAt(pixels, 10, 0);
        final leftMid = pixelAt(pixels, 0, 10);
        expect(isNonWhite(topMid) || isNonWhite(pixelAt(pixels, 10, 1)), isTrue,
            reason: 'Top border at row=0 should render');
        expect(isNonWhite(leftMid) || isNonWhite(pixelAt(pixels, 1, 10)), isTrue,
            reason: 'Left border at col=0 should render');
      });

      test('double border draws two sub-lines with gap', () async {
        // Use cell (2,2) for more room
        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(
            borders: CellBorders(
              top: BorderStyle(
                color: Color(0xFF000000),
                lineStyle: BorderLineStyle.double,
              ),
            ),
          ),
        );

        final pixels = await renderBorders(data);

        // Cell (2,2): top border at y=40. Double border: lines at y=39 and y=41 (±1).
        // The center y=40 should be the gap.
        // With half-pixel rounding: top = 40.0 rounded + 0.5 = 40.5
        // Outer sub-line at y offset -width = 40.5-1 → y≈39
        // Inner sub-line at y offset +width = 40.5+1 → y≈41
        final outerLine = pixelAt(pixels, 50, 39);
        final innerLine = pixelAt(pixels, 50, 41);

        expect(isNonWhite(outerLine), isTrue,
            reason: 'Outer sub-line of double border');
        expect(isNonWhite(innerLine), isTrue,
            reason: 'Inner sub-line of double border');
      });
    });

    group('conflict resolution', () {
      test('adjacent cells: thick right vs thin left — thick wins', () async {
        // Cell (1,1) has thick right border (width=3)
        data.setStyle(
          const CellCoordinate(1, 1),
          const CellStyle(
            borders: CellBorders(
              right: BorderStyle(
                color: Color(0xFFFF0000), // red
                width: 3.0,
                lineStyle: BorderLineStyle.solid,
              ),
            ),
          ),
        );

        // Cell (1,2) has thin left border (width=1)
        data.setStyle(
          const CellCoordinate(1, 2),
          const CellStyle(
            borders: CellBorders(
              left: BorderStyle(
                color: Color(0xFF0000FF), // blue
                width: 1.0,
                lineStyle: BorderLineStyle.solid,
              ),
            ),
          ),
        );

        final pixels = await renderBorders(data);

        // Shared edge at x=40 (right edge of (1,1), left edge of (1,2))
        // Thick (3px, red) should win over thin (1px, blue)
        final pixel = pixelAt(pixels, 40, 30);
        expect(isColor(pixel, const Color(0xFFFF0000)), isTrue,
            reason: 'Thick red border should win at shared edge');
      });

      test('adjacent cells: solid right vs double left — double wins',
          () async {
        // Cell (1,1) has solid right border
        data.setStyle(
          const CellCoordinate(1, 1),
          const CellStyle(
            borders: CellBorders(
              right: BorderStyle(
                color: Color(0xFFFF0000),
                width: 1.0,
                lineStyle: BorderLineStyle.solid,
              ),
            ),
          ),
        );

        // Cell (1,2) has double left border (same width, higher style priority)
        data.setStyle(
          const CellCoordinate(1, 2),
          const CellStyle(
            borders: CellBorders(
              left: BorderStyle(
                color: Color(0xFF0000FF),
                width: 1.0,
                lineStyle: BorderLineStyle.double,
              ),
            ),
          ),
        );

        final pixels = await renderBorders(data);

        // Double (index 4) > solid (index 3), so blue double should win.
        // Shared edge at x=40.5. Double border draws sub-lines at x≈39 and x≈41,
        // with a gap at x=40. Check the sub-line positions for blue pixels.
        final outerPixel = pixelAt(pixels, 39, 30);
        final innerPixel = pixelAt(pixels, 41, 30);
        expect(isColor(outerPixel, const Color(0xFF0000FF)), isTrue,
            reason: 'Outer sub-line of double (blue) should win at x=39');
        expect(isColor(innerPixel, const Color(0xFF0000FF)), isTrue,
            reason: 'Inner sub-line of double (blue) should win at x=41');
      });
    });

    group('corners', () {
      test('single cell solid border has filled corner pixels', () async {
        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(
              color: Color(0xFF000000),
              lineStyle: BorderLineStyle.solid,
            )),
          ),
        );

        final pixels = await renderBorders(data);

        // Cell (2,2): bounds left=40, top=40, right=60, bottom=60
        // Top-left corner area around (40, 40) should have pixels
        // The startExt/endExt extensions close corner gaps
        // Check that the corner region has non-white pixels
        final topLeftArea = [
          pixelAt(pixels, 40, 40),
          pixelAt(pixels, 39, 40),
          pixelAt(pixels, 40, 39),
          pixelAt(pixels, 41, 40),
          pixelAt(pixels, 40, 41),
        ];

        final hasCornerPixels = topLeftArea.any(isNonWhite);
        expect(hasCornerPixels, isTrue,
            reason: 'Corner area should have border pixels (L-join filled)');
      });

      test('all 4 sides solid produces clean rectangle', () async {
        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(
              color: Color(0xFF000000),
              lineStyle: BorderLineStyle.solid,
            )),
          ),
        );

        final pixels = await renderBorders(data);

        // Cell (2,2): bounds left=40, top=40, right=60, bottom=60
        // Check all 4 edges have continuous pixels
        var topEdgeCount = 0;
        var bottomEdgeCount = 0;
        var leftEdgeCount = 0;
        var rightEdgeCount = 0;

        for (var x = 40; x <= 60; x++) {
          if (isNonWhite(pixelAt(pixels, x, 40))) topEdgeCount++;
          if (isNonWhite(pixelAt(pixels, x, 60))) bottomEdgeCount++;
        }
        for (var y = 40; y <= 60; y++) {
          if (isNonWhite(pixelAt(pixels, 40, y))) leftEdgeCount++;
          if (isNonWhite(pixelAt(pixels, 60, y))) rightEdgeCount++;
        }

        // All edges should have substantial pixel coverage
        expect(topEdgeCount, greaterThan(15),
            reason: 'Top edge should be mostly filled');
        expect(bottomEdgeCount, greaterThan(15),
            reason: 'Bottom edge should be mostly filled');
        expect(leftEdgeCount, greaterThan(15),
            reason: 'Left edge should be mostly filled');
        expect(rightEdgeCount, greaterThan(15),
            reason: 'Right edge should be mostly filled');
      });
    });

    group('merge regions', () {
      test('merged 3x1 cell borders at merge outer edges only', () async {
        // Merge cells (1,1) through (1,3)
        data.mergeCells(const CellRange(1, 1, 1, 3));
        data.setStyle(
          const CellCoordinate(1, 1),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(
              color: Color(0xFF000000),
              lineStyle: BorderLineStyle.solid,
            )),
          ),
        );

        final pixels = await renderBorders(data);

        // Merged region (1,1)-(1,3): left=20, top=20, right=80, bottom=40
        // Left edge at x=20, right edge at x=80
        expect(isNonWhite(pixelAt(pixels, 20, 30)), isTrue,
            reason: 'Left border of merge at x=20');
        expect(isNonWhite(pixelAt(pixels, 80, 30)), isTrue,
            reason: 'Right border of merge at x=80');

        // Internal edges (x=40, x=60) should NOT have border pixels
        // (borders are only at the merge region boundary)
        expect(isWhite(pixelAt(pixels, 40, 30)), isTrue,
            reason: 'Internal edge at x=40 should not have border');
        expect(isWhite(pixelAt(pixels, 60, 30)), isTrue,
            reason: 'Internal edge at x=60 should not have border');
      });
    });

    group('double border junctions', () {
      // All 9 junction tests use the same 2x2 grid layout:
      //
      //   Cells (1,1), (1,2), (2,1), (2,2) each have double borders on
      //   all 4 sides. With 20px cells:
      //     (1,1): x=[20..40], y=[20..40]
      //     (1,2): x=[40..60], y=[20..40]
      //     (2,1): x=[20..40], y=[40..60]
      //     (2,2): x=[40..60], y=[40..60]
      //
      //   Grid intersections at (20,20), (40,20), (60,20),
      //                         (20,40), (40,40), (60,40),
      //                         (20,60), (40,60), (60,60).
      //
      //   Double border (width=1): outer sub-line at ±1px from gridline,
      //   gap at the gridline pixel. Every junction's 3x3 core must be:
      //     ■ ■ ■
      //     ■ □ ■
      //     ■ ■ ■
      //   i.e. 8 filled pixels surrounding a single white gap pixel,
      //   with NO solid line crossing through the gap.

      late ByteData pixels;

      setUp(() async {
        const doubleBorders = CellBorders.all(BorderStyle(
          color: Color(0xFF000000),
          lineStyle: BorderLineStyle.double,
        ));
        for (var r = 1; r <= 2; r++) {
          for (var c = 1; c <= 2; c++) {
            data.setStyle(
              CellCoordinate(r, c),
              const CellStyle(borders: doubleBorders),
            );
          }
        }
        pixels = await renderBorders(data);
      });

      /// Asserts the 3x3 pixel block at a **+ junction** (cx, cy) has the
      /// gap-preserving cross pattern where double borders continue through
      /// in all 4 directions:
      ///   ■ □ ■
      ///   □ □ □
      ///   ■ □ ■
      void expectPlusJunction3x3(int cx, int cy, String label) {
        // Center: white (both gap channels cross).
        expect(isWhite(pixelAt(pixels, cx, cy)), isTrue,
            reason: '$label: center ($cx,$cy) should be white gap');

        // 4 mid-edge pixels: white (gap channel preserved in both directions).
        expect(isWhite(pixelAt(pixels, cx, cy - 1)), isTrue,
            reason: '$label: top-center should be white (V gap)');
        expect(isWhite(pixelAt(pixels, cx - 1, cy)), isTrue,
            reason: '$label: mid-left should be white (H gap)');
        expect(isWhite(pixelAt(pixels, cx + 1, cy)), isTrue,
            reason: '$label: mid-right should be white (H gap)');
        expect(isWhite(pixelAt(pixels, cx, cy + 1)), isTrue,
            reason: '$label: bottom-center should be white (V gap)');

        // 4 corner pixels: filled (perpendicular sub-lines cross).
        expect(isNonWhite(pixelAt(pixels, cx - 1, cy - 1)), isTrue,
            reason: '$label: top-left corner should be filled');
        expect(isNonWhite(pixelAt(pixels, cx + 1, cy - 1)), isTrue,
            reason: '$label: top-right corner should be filled');
        expect(isNonWhite(pixelAt(pixels, cx - 1, cy + 1)), isTrue,
            reason: '$label: bottom-left corner should be filled');
        expect(isNonWhite(pixelAt(pixels, cx + 1, cy + 1)), isTrue,
            reason: '$label: bottom-right corner should be filled');
      }

      /// Asserts the 3x3 pixel block at an **L-corner or T-junction**
      /// (cx, cy) differs from the + junction pattern. The outer sub-lines
      /// extend through, filling more pixels than the cross pattern:
      ///
      /// L-corner example:  ■ ■ ■ / ■ □ □ / ■ □ ■
      /// T-junction example: ■ ■ ■ / □ □ □ / ■ □ ■
      ///
      /// Common invariant: center gap pixel is white, all 4 corners filled,
      /// and at least 5 of the 8 surrounding pixels are filled (more than
      /// the + junction's 4).
      void expectEdgeJunction3x3(int cx, int cy, String label) {
        // Center: white (gap channels still cross at the center).
        expect(isWhite(pixelAt(pixels, cx, cy)), isTrue,
            reason: '$label: center ($cx,$cy) should be white gap');

        // 4 corner pixels: always filled.
        expect(isNonWhite(pixelAt(pixels, cx - 1, cy - 1)), isTrue,
            reason: '$label: top-left corner should be filled');
        expect(isNonWhite(pixelAt(pixels, cx + 1, cy - 1)), isTrue,
            reason: '$label: top-right corner should be filled');
        expect(isNonWhite(pixelAt(pixels, cx - 1, cy + 1)), isTrue,
            reason: '$label: bottom-left corner should be filled');
        expect(isNonWhite(pixelAt(pixels, cx + 1, cy + 1)), isTrue,
            reason: '$label: bottom-right corner should be filled');

        // Count total filled among the 8 surrounding pixels. A + junction
        // has exactly 4 (the corners only). L-corners and T-junctions must
        // have more because the outer sub-lines extend through.
        final surroundingFilled = [
          isNonWhite(pixelAt(pixels, cx - 1, cy - 1)),
          isNonWhite(pixelAt(pixels, cx, cy - 1)),
          isNonWhite(pixelAt(pixels, cx + 1, cy - 1)),
          isNonWhite(pixelAt(pixels, cx - 1, cy)),
          isNonWhite(pixelAt(pixels, cx + 1, cy)),
          isNonWhite(pixelAt(pixels, cx - 1, cy + 1)),
          isNonWhite(pixelAt(pixels, cx, cy + 1)),
          isNonWhite(pixelAt(pixels, cx + 1, cy + 1)),
        ].where((b) => b).length;
        expect(surroundingFilled, greaterThanOrEqualTo(5),
            reason: '$label: should have >= 5 of 8 surrounding pixels filled '
                '(more than + junction\'s 4, got $surroundingFilled)');
      }

      // --- L-corners (2 borders meet, outer lines connect solidly) ---

      test('junction 1: top-left L-corner at (20,20)', () {
        expectEdgeJunction3x3(20, 20, 'Top-left L-corner');
      });

      test('junction 3: top-right L-corner at (60,20)', () {
        expectEdgeJunction3x3(60, 20, 'Top-right L-corner');
      });

      test('junction 7: bottom-left L-corner at (20,60)', () {
        expectEdgeJunction3x3(20, 60, 'Bottom-left L-corner');
      });

      test('junction 9: bottom-right L-corner at (60,60)', () {
        expectEdgeJunction3x3(60, 60, 'Bottom-right L-corner');
      });

      // --- T-junctions (3 borders meet, outer lines connect on edge side) ---

      test('junction 2: top-center T at (40,20)', () {
        expectEdgeJunction3x3(40, 20, 'Top-center T');
      });

      test('junction 4: mid-left T at (20,40)', () {
        expectEdgeJunction3x3(20, 40, 'Mid-left T');
      });

      test('junction 6: mid-right T at (60,40)', () {
        expectEdgeJunction3x3(60, 40, 'Mid-right T');
      });

      test('junction 8: bottom-center T at (40,60)', () {
        expectEdgeJunction3x3(40, 60, 'Bottom-center T');
      });

      // --- + junction (all 4 borders meet, full gap preservation) ---

      test('junction 5: center + at (40,40)', () {
        expectPlusJunction3x3(40, 40, 'Center +');
      });

      test('inner sub-lines exist mid-edge (not just at junctions)', () {
        // Horizontal inner sub-lines at y=21 and y=41 (inner offset from
        // top borders of row 1 and row 2)
        expect(isNonWhite(pixelAt(pixels, 30, 21)), isTrue,
            reason: 'Horizontal inner sub-line at mid-edge (30,21)');
        expect(isNonWhite(pixelAt(pixels, 50, 21)), isTrue,
            reason: 'Horizontal inner sub-line at mid-edge (50,21)');
        expect(isNonWhite(pixelAt(pixels, 30, 41)), isTrue,
            reason: 'Horizontal inner sub-line at mid-edge (30,41)');
        expect(isNonWhite(pixelAt(pixels, 50, 41)), isTrue,
            reason: 'Horizontal inner sub-line at mid-edge (50,41)');

        // Vertical inner sub-lines at x=21 and x=41
        expect(isNonWhite(pixelAt(pixels, 21, 30)), isTrue,
            reason: 'Vertical inner sub-line at mid-edge (21,30)');
        expect(isNonWhite(pixelAt(pixels, 21, 50)), isTrue,
            reason: 'Vertical inner sub-line at mid-edge (21,50)');
        expect(isNonWhite(pixelAt(pixels, 41, 30)), isTrue,
            reason: 'Vertical inner sub-line at mid-edge (41,30)');
        expect(isNonWhite(pixelAt(pixels, 41, 50)), isTrue,
            reason: 'Vertical inner sub-line at mid-edge (41,50)');
      });

      test('inner sub-line does not leak past outer at isolated cell', () async {
        // Separate data with a single cell — L-junction corners.
        final singleData = SparseWorksheetData(rowCount: 5, columnCount: 5);
        singleData.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(
              color: Color(0xFF000000),
              lineStyle: BorderLineStyle.double,
            )),
          ),
        );

        final singlePixels = await renderBorders(singleData);
        singleData.dispose();

        // Cell (2,2): bounds left=40, top=40, right=60, bottom=60
        // Top border inner at y≈41. The inner should not leak past the
        // outer's lateral extent.
        expect(isWhite(pixelAt(singlePixels, 38, 41)), isTrue,
            reason: 'Inner should not leak left past outer');
        expect(isWhite(pixelAt(singlePixels, 62, 41)), isTrue,
            reason: 'Inner should not leak right past outer');
      });
    });

    group('widthScale', () {
      test('widthScale > 1.0 makes borders thicker', () async {
        final layoutSolver = LayoutSolver(
          rows: SpanList(count: 5, defaultSize: 20.0),
          columns: SpanList(count: 5, defaultSize: 20.0),
        );

        data.setStyle(
          const CellCoordinate(2, 2),
          const CellStyle(
            borders: CellBorders(
              top: BorderStyle(
                color: Color(0xFF000000),
                lineStyle: BorderLineStyle.solid,
                width: 1.0,
              ),
            ),
          ),
        );

        // Render with widthScale=2.0
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(
          recorder,
          const Rect.fromLTWH(0, 0, 100, 100),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          Paint()..color = const Color(0xFFFFFFFF),
        );

        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..isAntiAlias = false;

        CellBorderRenderer.renderBorders(
          canvas: canvas,
          borderPaint: borderPaint,
          data: data,
          mergedCells: null,
          startRow: 0,
          endRow: 4,
          startCol: 0,
          endCol: 4,
          maxRow: 4,
          maxCol: 4,
          getBounds: (coord) => layoutSolver.getCellBounds(coord),
          widthScale: 2.0,
        );

        final picture = recorder.endRecording();
        final image = await picture.toImage(100, 100);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        picture.dispose();
        image.dispose();

        // Cell (2,2): top at y=40. With strokeWidth=2.0 (width 1.0 * scale 2.0),
        // the line should be 2px wide, covering y=40 and y=41 (or y=39 and y=40).
        var nonWhiteCount = 0;
        for (var dy = 38; dy <= 43; dy++) {
          if (isNonWhite(pixelAt(byteData!, 50, dy))) nonWhiteCount++;
        }
        expect(nonWhiteCount, greaterThanOrEqualTo(2),
            reason: 'widthScale=2.0 should produce a 2px wide border line');
      });
    });
  });
}
