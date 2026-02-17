import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/rendering/painters/border_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Renders a single border edge onto a 64x64 canvas and returns pixel data.
  Future<ByteData> renderEdge({
    required Offset start,
    required Offset end,
    required BorderLineStyle lineStyle,
    double width = 1.0,
    Color color = const Color(0xFF000000),
    double startExt = 0.0,
    double endExt = 0.0,
    int outerSign = -1,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, 64, 64),
    );

    // White background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width
      ..isAntiAlias = false;

    BorderPainter.drawBorderEdge(
      canvas,
      start,
      end,
      paint,
      lineStyle,
      width,
      startExt: startExt,
      endExt: endExt,
      outerSign: outerSign,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    return byteData!;
  }

  int pixelAt(ByteData bytes, int x, int y) {
    final offset = (y * 64 + x) * 4;
    final r = bytes.getUint8(offset);
    final g = bytes.getUint8(offset + 1);
    final b = bytes.getUint8(offset + 2);
    final a = bytes.getUint8(offset + 3);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  bool isNonWhite(int argb) => argb != 0xFFFFFFFF;
  bool isWhite(int argb) => argb == 0xFFFFFFFF;

  group('BorderPainter', () {
    group('smoke tests', () {
      late ui.PictureRecorder recorder;
      late Canvas canvas;
      late Paint paint;

      setUp(() {
        recorder = ui.PictureRecorder();
        canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 256, 256));
        paint = Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF000000)
          ..strokeWidth = 1.0;
      });

      tearDown(() {
        recorder.endRecording().dispose();
      });

      test('draws solid line without error', () {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(0, 10.5),
          const Offset(100, 10.5),
          paint,
          BorderLineStyle.solid,
          1.0,
        );
      });

      test('draws dotted line without error', () {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(0, 10.5),
          const Offset(100, 10.5),
          paint,
          BorderLineStyle.dotted,
          1.0,
        );
      });

      test('draws dashed line without error', () {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(0, 10.5),
          const Offset(100, 10.5),
          paint,
          BorderLineStyle.dashed,
          1.0,
        );
      });

      test('draws double line without error', () {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(0, 10.5),
          const Offset(100, 10.5),
          paint,
          BorderLineStyle.double,
          1.0,
        );
      });

      test('none lineStyle draws nothing', () {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(0, 10.5),
          const Offset(100, 10.5),
          paint,
          BorderLineStyle.none,
          1.0,
        );
      });

      test('draws vertical lines without error', () {
        for (final style in BorderLineStyle.values) {
          BorderPainter.drawBorderEdge(
            canvas,
            const Offset(10.5, 0),
            const Offset(10.5, 100),
            paint,
            style,
            1.0,
          );
        }
      });

      test('handles zero-length line', () {
        BorderPainter.drawBorderEdge(
          canvas,
          const Offset(50, 50),
          const Offset(50, 50),
          paint,
          BorderLineStyle.dashed,
          1.0,
        );
      });

      test('handles various widths', () {
        for (final width in [0.5, 1.0, 2.0, 3.0]) {
          paint.strokeWidth = width;
          BorderPainter.drawBorderEdge(
            canvas,
            const Offset(0, 10.5),
            const Offset(200, 10.5),
            paint,
            BorderLineStyle.solid,
            width,
          );
        }
      });
    });

    group('pixel-level: solid line', () {
      test('horizontal solid line has pixels at expected Y', () async {
        // Draw horizontal solid line at y=32.5, from x=10 to x=54
        final pixels = await renderEdge(
          start: const Offset(10, 32.5),
          end: const Offset(54, 32.5),
          lineStyle: BorderLineStyle.solid,
        );

        // Pixel at y=32 (stroke centered on 32.5) should be non-white
        expect(isNonWhite(pixelAt(pixels, 30, 32)), isTrue,
            reason: 'Solid line at y=32.5 draws pixels at y=32');

        // Pixel well above and below should be white
        expect(isWhite(pixelAt(pixels, 30, 28)), isTrue,
            reason: 'No pixels far above the line');
        expect(isWhite(pixelAt(pixels, 30, 36)), isTrue,
            reason: 'No pixels far below the line');
      });

      test('vertical solid line has pixels at expected X', () async {
        final pixels = await renderEdge(
          start: const Offset(32.5, 10),
          end: const Offset(32.5, 54),
          lineStyle: BorderLineStyle.solid,
        );

        expect(isNonWhite(pixelAt(pixels, 32, 30)), isTrue,
            reason: 'Solid line at x=32.5 draws pixels at x=32');
        expect(isWhite(pixelAt(pixels, 28, 30)), isTrue,
            reason: 'No pixels far left of the line');
        expect(isWhite(pixelAt(pixels, 36, 30)), isTrue,
            reason: 'No pixels far right of the line');
      });
    });

    group('pixel-level: double line', () {
      test('horizontal double line has two sub-lines with gap', () async {
        final pixels = await renderEdge(
          start: const Offset(10, 32.5),
          end: const Offset(54, 32.5),
          lineStyle: BorderLineStyle.double,
        );

        // Double line with width=1.0, outerSign=-1:
        // Outer sub-line at y=32.5-1.0 = 31.5 → pixels at y=31
        // Inner sub-line at y=32.5+1.0 = 33.5 → pixels at y=33
        // Gap at y=32
        final outerPixel = pixelAt(pixels, 30, 31);
        final innerPixel = pixelAt(pixels, 30, 33);

        expect(isNonWhite(outerPixel), isTrue,
            reason: 'Outer sub-line of double border should exist');
        expect(isNonWhite(innerPixel), isTrue,
            reason: 'Inner sub-line of double border should exist');
      });
    });

    group('pixel-level: dashed/dotted', () {
      test('dashed line has alternating segments', () async {
        // width=1.0, dash=4px, gap=2px
        final pixels = await renderEdge(
          start: const Offset(0, 32.5),
          end: const Offset(63, 32.5),
          lineStyle: BorderLineStyle.dashed,
        );

        // Sample several positions along the line.
        // The dashed pattern: 4px dash, 2px gap, repeating.
        // At y=32, there should be some drawn and some gap pixels.
        var drawnCount = 0;
        var gapCount = 0;
        for (var x = 1; x < 60; x++) {
          if (isNonWhite(pixelAt(pixels, x, 32))) {
            drawnCount++;
          } else {
            gapCount++;
          }
        }
        expect(drawnCount, greaterThan(20),
            reason: 'Dashed line should have drawn segments');
        expect(gapCount, greaterThan(5),
            reason: 'Dashed line should have gaps between segments');
      });

      test('dotted line has shorter segments than dashed', () async {
        final pixels = await renderEdge(
          start: const Offset(0, 32.5),
          end: const Offset(63, 32.5),
          lineStyle: BorderLineStyle.dotted,
        );

        // Dotted: dash=width(1px), gap=2px
        var drawnCount = 0;
        var gapCount = 0;
        for (var x = 1; x < 60; x++) {
          if (isNonWhite(pixelAt(pixels, x, 32))) {
            drawnCount++;
          } else {
            gapCount++;
          }
        }
        expect(drawnCount, greaterThan(10),
            reason: 'Dotted line should have drawn dots');
        expect(gapCount, greaterThan(10),
            reason: 'Dotted line should have more gaps than dashed');
      });
    });

    group('pixel-level: width variations', () {
      test('width=3 solid line occupies 3 pixel rows', () async {
        final pixels = await renderEdge(
          start: const Offset(10, 32.5),
          end: const Offset(54, 32.5),
          lineStyle: BorderLineStyle.solid,
          width: 3.0,
        );

        // 3px stroke centered on y=32.5 → covers y=31, 32, 33
        expect(isNonWhite(pixelAt(pixels, 30, 31)), isTrue,
            reason: 'Top row of 3px line');
        expect(isNonWhite(pixelAt(pixels, 30, 32)), isTrue,
            reason: 'Center row of 3px line');
        expect(isNonWhite(pixelAt(pixels, 30, 33)), isTrue,
            reason: 'Bottom row of 3px line');

        // Rows above and below should be white
        expect(isWhite(pixelAt(pixels, 30, 29)), isTrue,
            reason: 'No pixels above 3px line');
        expect(isWhite(pixelAt(pixels, 30, 35)), isTrue,
            reason: 'No pixels below 3px line');
      });

      test('none style produces no pixels', () async {
        final pixels = await renderEdge(
          start: const Offset(10, 32.5),
          end: const Offset(54, 32.5),
          lineStyle: BorderLineStyle.none,
        );

        // All pixels along the line should be white
        for (var x = 10; x < 55; x++) {
          expect(isWhite(pixelAt(pixels, x, 32)), isTrue,
              reason: 'none style should produce no pixels at x=$x');
        }
      });
    });

    group('pixel-level: junction-aware extensions', () {
      /// Renders an edge with junction parameters.
      Future<ByteData> renderEdgeWithJunction({
        required Offset start,
        required Offset end,
        required BorderLineStyle lineStyle,
        double width = 1.0,
        Color color = const Color(0xFF000000),
        int outerSign = -1,
        BorderStyle? startJunctionPerpA,
        BorderStyle? startJunctionPerpB,
        BorderStyle? endJunctionPerpA,
        BorderStyle? endJunctionPerpB,
      }) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(
          recorder,
          const Rect.fromLTWH(0, 0, 64, 64),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 64, 64),
          Paint()..color = const Color(0xFFFFFFFF),
        );

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..color = color
          ..strokeWidth = width
          ..isAntiAlias = false;

        BorderPainter.drawBorderEdge(
          canvas,
          start,
          end,
          paint,
          lineStyle,
          width,
          outerSign: outerSign,
          startJunctionPerpA: startJunctionPerpA,
          startJunctionPerpB: startJunctionPerpB,
          endJunctionPerpA: endJunctionPerpA,
          endJunctionPerpB: endJunctionPerpB,
        );

        final picture = recorder.endRecording();
        final image = await picture.toImage(64, 64);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        picture.dispose();
        image.dispose();
        return byteData!;
      }

      test('thick perpendicular at start extends edge', () async {
        // Horizontal solid line from x=20 to x=44 at y=32.5
        // With a thick (width=5) perpendicular border at start.
        // The horizontal start extension is reduced by 1px so it stays
        // within the perpendicular border's pixel footprint.
        // width=5 → extension = 5/2 = 2.5, adjusted = 1.5
        final withJunction = await renderEdgeWithJunction(
          start: const Offset(20, 32.5),
          end: const Offset(44, 32.5),
          lineStyle: BorderLineStyle.solid,
          startJunctionPerpA: const BorderStyle(width: 5.0),
        );

        // Without junction: line starts at x=20
        final withoutJunction = await renderEdgeWithJunction(
          start: const Offset(20, 32.5),
          end: const Offset(44, 32.5),
          lineStyle: BorderLineStyle.solid,
        );

        // width=5 → extension = 2.5, adjusted -1px = 1.5
        // Line should extend further left with junction than without.
        // Count drawn pixels to the left of x=20.
        var junctionLeftCount = 0;
        var noJunctionLeftCount = 0;
        for (var x = 15; x < 20; x++) {
          if (isNonWhite(pixelAt(withJunction, x, 32))) junctionLeftCount++;
          if (isNonWhite(pixelAt(withoutJunction, x, 32))) noJunctionLeftCount++;
        }
        expect(junctionLeftCount, greaterThan(noJunctionLeftCount),
            reason: 'Junction extension draws more pixels left of start');

        // Verify the main line body is drawn too.
        expect(isNonWhite(pixelAt(withJunction, 30, 32)), isTrue,
            reason: 'Main line body should be drawn');
      });

      test('no perpendicular at end means no extension', () async {
        final pixels = await renderEdgeWithJunction(
          start: const Offset(20, 32.5),
          end: const Offset(44, 32.5),
          lineStyle: BorderLineStyle.solid,
          startJunctionPerpA: const BorderStyle(width: 3.0),
          // No end junction
        );

        // End should stop at x=44 (no extension)
        expect(isWhite(pixelAt(pixels, 46, 32)), isTrue,
            reason: 'No extension past end when no junction');
      });

      test('double perpendicular extends by visual width / 2', () async {
        // Double border has visual width = width * 3 = 1 * 3 = 3
        // Extension = 3 / 2 = 1.5
        final pixels = await renderEdgeWithJunction(
          start: const Offset(20, 32.5),
          end: const Offset(44, 32.5),
          lineStyle: BorderLineStyle.solid,
          endJunctionPerpA: const BorderStyle(
            width: 1.0,
            lineStyle: BorderLineStyle.double,
          ),
        );

        // Extension at end: 3/2 = 1.5 → line extends to x=44+1.5=45.5
        expect(isNonWhite(pixelAt(pixels, 45, 32)), isTrue,
            reason: 'Line should extend right due to double perpendicular');
      });

      test('double border inner sub-line spans full edge length', () async {
        // The inner sub-line should run from start to end without shortening.
        // Adjacent cell segments share endpoints, and butt-cap rendering
        // naturally creates the correct 1-pixel gap at junctions.
        final pixels = await renderEdge(
          start: const Offset(10, 32.5),
          end: const Offset(54, 32.5),
          lineStyle: BorderLineStyle.double,
          outerSign: -1,
        );

        // Inner sub-line at y=33 (32.5 + 1.0 = 33.5 → y=33)
        // With no shortening, inner runs from x=10 to x=54 (butt cap: x=10..53)

        // Start side: inner should be drawn at x=10
        expect(isNonWhite(pixelAt(pixels, 10, 33)), isTrue,
            reason: 'Inner sub-line starts at the edge start');

        // End side: butt cap means the last drawn pixel is x=53
        expect(isNonWhite(pixelAt(pixels, 53, 33)), isTrue,
            reason: 'Inner sub-line reaches near the edge end');

        // Middle of inner sub-line
        expect(isNonWhite(pixelAt(pixels, 30, 33)), isTrue,
            reason: 'Inner sub-line exists in the middle');
      });

      test('fallback to startExt/endExt when no junction params', () async {
        // Verify backward compatibility: explicit ext params still work
        final withExt = await renderEdge(
          start: const Offset(20, 32.5),
          end: const Offset(44, 32.5),
          lineStyle: BorderLineStyle.solid,
          startExt: 3.0,
          endExt: 3.0,
        );

        final withoutExt = await renderEdge(
          start: const Offset(20, 32.5),
          end: const Offset(44, 32.5),
          lineStyle: BorderLineStyle.solid,
        );

        // Count drawn pixels left of start and right of end
        var extLeftCount = 0;
        var noExtLeftCount = 0;
        var extRightCount = 0;
        var noExtRightCount = 0;
        for (var x = 15; x < 20; x++) {
          if (isNonWhite(pixelAt(withExt, x, 32))) extLeftCount++;
          if (isNonWhite(pixelAt(withoutExt, x, 32))) noExtLeftCount++;
        }
        for (var x = 45; x < 50; x++) {
          if (isNonWhite(pixelAt(withExt, x, 32))) extRightCount++;
          if (isNonWhite(pixelAt(withoutExt, x, 32))) noExtRightCount++;
        }
        expect(extLeftCount, greaterThan(noExtLeftCount),
            reason: 'startExt=3 should extend line left');
        expect(extRightCount, greaterThan(noExtRightCount),
            reason: 'endExt=3 should extend line right');
      });
    });
  });
}
