import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/formula/formula_tokenizer.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/rendering/layers/formula_reference_layer.dart';
import 'package:worksheet/src/rendering/layers/render_layer.dart';

void main() {
  late LayoutSolver layoutSolver;

  setUp(() {
    layoutSolver = LayoutSolver(
      rows: SpanList(count: 100, defaultSize: 24.0),
      columns: SpanList(count: 26, defaultSize: 100.0),
    );
  });

  group('FormulaReferenceLayer', () {
    test('has order 95', () {
      final layer = FormulaReferenceLayer(layoutSolver: layoutSolver);
      expect(layer.order, 95);
    });

    test('empty references paints nothing without error', () {
      final layer = FormulaReferenceLayer(layoutSolver: layoutSolver);
      layer.references = [];

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(
        LayerPaintContext(
          canvas: canvas,
          viewportSize: const Size(800, 600),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        ),
      );

      // No exception means success.
      recorder.endRecording();
    });

    test('single reference paints without error', () {
      final layer = FormulaReferenceLayer(layoutSolver: layoutSolver);
      layer.references = [
        FormulaToken(
          start: 1,
          end: 3,
          text: 'A1',
          cell: const CellCoordinate(0, 0),
          color: const Color(0xFF0070C0),
        ),
      ];

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(
        LayerPaintContext(
          canvas: canvas,
          viewportSize: const Size(800, 600),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        ),
      );

      recorder.endRecording();
    });

    test('range reference paints without error', () {
      final layer = FormulaReferenceLayer(layoutSolver: layoutSolver);
      layer.references = [
        FormulaToken(
          start: 1,
          end: 6,
          text: 'A1:C5',
          cell: const CellCoordinate(0, 0),
          range: const CellRange(0, 0, 4, 2),
          color: const Color(0xFF0070C0),
        ),
      ];

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(
        LayerPaintContext(
          canvas: canvas,
          viewportSize: const Size(800, 600),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        ),
      );

      recorder.endRecording();
    });

    test('active reference paints marching ants without error', () {
      final layer = FormulaReferenceLayer(layoutSolver: layoutSolver);
      layer.references = [
        FormulaToken(
          start: 1,
          end: 3,
          text: 'A1',
          cell: const CellCoordinate(0, 0),
          color: const Color(0xFF0070C0),
        ),
      ];
      layer.activeIndex = 0;
      layer.animationValue = 0.5;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      layer.paint(
        LayerPaintContext(
          canvas: canvas,
          viewportSize: const Size(800, 600),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        ),
      );

      recorder.endRecording();
    });

    test('calls onNeedsPaint when markNeedsPaint is called', () {
      var paintCount = 0;
      final layer = FormulaReferenceLayer(
        layoutSolver: layoutSolver,
        onNeedsPaint: () => paintCount++,
      );

      expect(paintCount, 0);
      layer.markNeedsPaint();
      expect(paintCount, 1);
    });

    test('disabled layer does not paint', () {
      final layer = FormulaReferenceLayer(layoutSolver: layoutSolver);
      layer.enabled = false;
      layer.references = [
        FormulaToken(
          start: 1,
          end: 3,
          text: 'A1',
          cell: const CellCoordinate(0, 0),
          color: const Color(0xFF0070C0),
        ),
      ];

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Should not paint anything (no error either).
      layer.paint(
        LayerPaintContext(
          canvas: canvas,
          viewportSize: const Size(800, 600),
          scrollOffset: Offset.zero,
          zoom: 1.0,
        ),
      );

      recorder.endRecording();
    });
  });
}
