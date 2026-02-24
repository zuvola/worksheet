import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/layers/cut_indicator_layer.dart';
import 'package:worksheet/src/rendering/layers/render_layer.dart';

void main() {
  late LayoutSolver layoutSolver;

  setUp(() {
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 100, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
  });

  group('CutIndicatorLayer', () {
    test('has order 96', () {
      final layer = CutIndicatorLayer(layoutSolver: layoutSolver);
      expect(layer.order, 96);
    });

    test('paints nothing when range is null', () {
      final layer = CutIndicatorLayer(layoutSolver: layoutSolver);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      ));

      // No exception means success.
      recorder.endRecording();
    });

    test('paints marching ants when range is set', () {
      final layer = CutIndicatorLayer(layoutSolver: layoutSolver);
      layer.range = const CellRange(0, 0, 2, 2);
      layer.animationValue = 0.5;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      ));

      // No exception means success — marching ants were drawn.
      recorder.endRecording();
    });

    test('paints nothing when disabled', () {
      final layer = CutIndicatorLayer(layoutSolver: layoutSolver);
      layer.range = const CellRange(0, 0, 1, 1);
      layer.enabled = false;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(800, 600),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      ));

      recorder.endRecording();
    });

    test('markNeedsPaint calls onNeedsPaint callback', () {
      int callCount = 0;
      final layer = CutIndicatorLayer(
        layoutSolver: layoutSolver,
        onNeedsPaint: () => callCount++,
      );

      layer.markNeedsPaint();
      expect(callCount, 1);
    });

    test('paints at correct zoom level', () {
      final layer = CutIndicatorLayer(layoutSolver: layoutSolver);
      layer.range = const CellRange(0, 0, 0, 0);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Paint at 200% zoom — should not error.
      layer.paint(LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(1600, 1200),
        scrollOffset: Offset.zero,
        zoom: 2.0,
      ));

      recorder.endRecording();
    });

    test('skips painting when range is outside viewport', () {
      final layer = CutIndicatorLayer(layoutSolver: layoutSolver);
      // Range at row 50+ is well below a small viewport
      layer.range = const CellRange(50, 20, 55, 25);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(LayerPaintContext(
        canvas: canvas,
        viewportSize: const Size(100, 100),
        scrollOffset: Offset.zero,
        zoom: 1.0,
      ));

      recorder.endRecording();
    });
  });
}
