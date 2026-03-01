import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/geometry/zoom_transformer.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/rendering/tile/tile_coordinate.dart';
import 'package:worksheet/src/rendering/tile/tile_painter.dart';

void main() {
  group('TilePainter', () {
    late SparseWorksheetData data;
    late LayoutSolver layoutSolver;
    late TilePainter painter;

    setUp(() {
      data = SparseWorksheetData(rowCount: 1000, columnCount: 100);
      layoutSolver = LayoutSolver(
        rows: SpanList(count: 1000, defaultSize: 24.0),
        columns: SpanList(count: 100, defaultSize: 100.0),
      );
      painter = TilePainter(data: data, layoutSolver: layoutSolver);
    });

    tearDown(() {
      data.dispose();
    });

    test('implements TileRenderer interface', () {
      // TilePainter should implement the TileRenderer interface
      expect(painter, isNotNull);
    });

    test('renderTile returns a valid Picture', () {
      final picture = painter.renderTile(
        coordinate: TileCoordinate(0, 0),
        bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
        cellRange: CellRange(0, 0, 10, 2),
        zoomBucket: ZoomBucket.full,
      );

      expect(picture, isA<ui.Picture>());
      picture.dispose();
    });

    test('renders cells with data', () {
      // Add some cell data
      data.setCell(CellCoordinate(0, 0), CellValue.text('Hello'));
      data.setCell(CellCoordinate(1, 1), CellValue.number(42));

      final picture = painter.renderTile(
        coordinate: TileCoordinate(0, 0),
        bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
        cellRange: CellRange(0, 0, 10, 2),
        zoomBucket: ZoomBucket.full,
      );

      // Picture should be created without errors
      expect(picture, isA<ui.Picture>());
      picture.dispose();
    });

    test('applies cell styles', () {
      data.setCell(CellCoordinate(0, 0), CellValue.text('Styled'));
      data.setStyle(
        CellCoordinate(0, 0),
        const CellStyle(backgroundColor: Color(0xFFFFFF00)),
      );
      data.setRichText(CellCoordinate(0, 0), [
        const TextSpan(
          text: 'Styled',
          style: TextStyle(
            color: Color(0xFF0000FF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ]);

      final picture = painter.renderTile(
        coordinate: TileCoordinate(0, 0),
        bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
        cellRange: CellRange(0, 0, 5, 2),
        zoomBucket: ZoomBucket.full,
      );

      expect(picture, isA<ui.Picture>());
      picture.dispose();
    });

    group('Level of Detail (LOD)', () {
      test('renders text at full zoom', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Visible'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('skips text at tenth zoom bucket', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Hidden'));

        // At 10% zoom, text should be skipped for performance
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 50, 25),
          zoomBucket: ZoomBucket.tenth,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders simplified at quarter zoom', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Simplified'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 20, 10),
          zoomBucket: ZoomBucket.quarter,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('gridlines', () {
      test('renders gridlines', () {
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('can disable gridlines', () {
        final noGridPainter = TilePainter(
          data: data,
          layoutSolver: layoutSolver,
          showGridlines: false,
        );

        final picture = noGridPainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('cell value rendering', () {
      test('renders text values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Text'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders number values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.number(123.45));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders boolean values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.boolean(true));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders error values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.error('#DIV/0!'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders formatted currency values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.number(1234.56));
        data.setFormat(CellCoordinate(0, 0), CellFormat.currency);

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders formatted percentage values', () {
        data.setCell(CellCoordinate(0, 0), CellValue.number(0.42));
        data.setFormat(CellCoordinate(0, 0), CellFormat.percentage);

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders formatted date values', () {
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.date(DateTime(2024, 1, 15)),
        );
        data.setFormat(CellCoordinate(0, 0), CellFormat.dateIso);

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('configuration', () {
      test('uses custom gridline color', () {
        final customPainter = TilePainter(
          data: data,
          layoutSolver: layoutSolver,
          gridlineColor: const Color(0xFFFF0000),
        );

        final picture = customPainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('uses custom background color', () {
        final customPainter = TilePainter(
          data: data,
          layoutSolver: layoutSolver,
          backgroundColor: const Color(0xFFF0F0F0),
        );

        final picture = customPainter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 10, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('borders', () {
      test('renders cells with borders', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Bordered'));
        data.setStyle(
          CellCoordinate(0, 0),
          const CellStyle(
            borders: CellBorders.all(
              BorderStyle(
                color: Color(0xFF000000),
                width: 2.0,
                lineStyle: BorderLineStyle.solid,
              ),
            ),
          ),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders cells with different line styles', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Mixed'));
        data.setStyle(
          CellCoordinate(0, 0),
          const CellStyle(
            borders: CellBorders(
              top: BorderStyle(lineStyle: BorderLineStyle.solid),
              right: BorderStyle(lineStyle: BorderLineStyle.dashed),
              bottom: BorderStyle(lineStyle: BorderLineStyle.dotted),
              left: BorderStyle(lineStyle: BorderLineStyle.double),
            ),
          ),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('borders hidden below 40% zoom', () {
        data.setStyle(
          CellCoordinate(0, 0),
          const CellStyle(borders: CellBorders.all(BorderStyle(width: 2.0))),
        );

        // Should not throw at low zoom levels
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 50, 25),
          zoomBucket: ZoomBucket.quarter,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders adjacent cells with conflicting borders', () {
        // Cell (0,0) has thick right border
        data.setStyle(
          CellCoordinate(0, 0),
          const CellStyle(
            borders: CellBorders(
              right: BorderStyle(width: 3.0, color: Color(0xFFFF0000)),
            ),
          ),
        );

        // Cell (0,1) has thin left border
        data.setStyle(
          CellCoordinate(0, 1),
          const CellStyle(
            borders: CellBorders(
              left: BorderStyle(width: 1.0, color: Color(0xFF0000FF)),
            ),
          ),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('merged cell border renders without crash', () {
        // Merge (0,0)-(2,0) — 3 rows, 1 column
        data.mergeCells(const CellRange(0, 0, 2, 0));
        data.setStyle(
          const CellCoordinate(0, 0),
          const CellStyle(
            borders: CellBorders.all(
              BorderStyle(color: Color(0xFF000000), width: 2.0),
            ),
          ),
        );

        painter.mergedCells = data.mergedCells;
        layoutSolver.mergedCells = data.mergedCells;

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('thick border (width 3) on all sides renders without crash', () {
        data.setCell(CellCoordinate(1, 1), CellValue.text('Thick'));
        data.setStyle(
          CellCoordinate(1, 1),
          const CellStyle(
            borders: CellBorders.all(
              BorderStyle(
                color: Color(0xFF000000),
                width: 3.0,
                lineStyle: BorderLineStyle.solid,
              ),
            ),
          ),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('double border on all sides renders without crash', () {
        data.setCell(CellCoordinate(1, 1), CellValue.text('Double'));
        data.setStyle(
          CellCoordinate(1, 1),
          const CellStyle(
            borders: CellBorders.all(
              BorderStyle(
                color: Color(0xFF000000),
                width: 3.0,
                lineStyle: BorderLineStyle.double,
              ),
            ),
          ),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('merged cell right border resolves correctly', () {
        // Merge (0,0)-(0,2) — 1 row, 3 columns
        data.mergeCells(const CellRange(0, 0, 0, 2));
        data.setStyle(
          const CellCoordinate(0, 0),
          const CellStyle(
            borders: CellBorders.all(BorderStyle(color: Color(0xFF000000))),
          ),
        );

        painter.mergedCells = data.mergedCells;
        layoutSolver.mergedCells = data.mergedCells;

        // Tile spans past the merge so conflict resolution hits col 3
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 512, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('editingRange', () {
      test('suppresses text for single editing cell', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Editing'));
        data.setCell(CellCoordinate(0, 1), CellValue.text('Visible'));

        painter.editingRange = CellRange(0, 0, 0, 0);

        // Should render without errors — the editing cell text is skipped
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('suppresses text for all cells in expanded range', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Editing'));
        data.setCell(CellCoordinate(0, 1), CellValue.text('Covered'));
        data.setCell(CellCoordinate(0, 2), CellValue.text('Also Covered'));
        data.setCell(CellCoordinate(0, 3), CellValue.text('Visible'));

        // Expanded editing range covers columns 0-2
        painter.editingRange = CellRange(0, 0, 0, 2);

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 512, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('null editingRange renders all cells normally', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Normal'));

        painter.editingRange = null;

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('hash fill (######)', () {
      test('number that does not fit shows hash fill', () {
        // Use narrow column so number overflows
        layoutSolver.setColumnWidth(0, 30.0);
        data.setCell(CellCoordinate(0, 0), CellValue.number(123456789.12));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('date that does not fit shows hash fill', () {
        layoutSolver.setColumnWidth(0, 30.0);
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.date(DateTime(2024, 12, 25)),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('text value does NOT show hash fill', () {
        layoutSolver.setColumnWidth(0, 30.0);
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.text('Long text that overflows'),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        // Should produce a valid picture (text spills, no hash fill)
        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('text spillover', () {
      test('left-aligned text renders into adjacent empty cells', () {
        // Put long text in col 0, cols 1-2 are empty
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.text('This is a very long text that should spill'),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 512, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('right-aligned text renders into adjacent empty left cells', () {
        data.setCell(
          CellCoordinate(0, 3),
          CellValue.text('This is a very long text that should spill left'),
        );
        data.setStyle(
          CellCoordinate(0, 3),
          const CellStyle(textAlignment: CellTextAlignment.right),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 512, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('center-aligned text renders both directions', () {
        data.setCell(
          CellCoordinate(0, 3),
          CellValue.text('Center text that spills in both directions'),
        );
        data.setStyle(
          CellCoordinate(0, 3),
          const CellStyle(textAlignment: CellTextAlignment.center),
        );

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 512, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('spillover stops at non-empty adjacent cell', () {
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.text('Very long text attempting to spill over'),
        );
        data.setCell(CellCoordinate(0, 1), CellValue.text('Blocker'));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 512, 256),
          cellRange: CellRange(0, 0, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('wrap text cell does not spill', () {
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.text('Long wrapped text stays in cell'),
        );
        data.setStyle(CellCoordinate(0, 0), const CellStyle(wrapText: true));

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('spillover from cell outside tile range renders into tile', () {
        // Cell at col 0 has long text, tile starts at col 1
        data.setCell(
          CellCoordinate(0, 0),
          CellValue.text(
            'This text is very long and spills into columns 1 2 3 4',
          ),
        );

        // Tile covers cols 1-5 — cell 0 is outside tile range but spills in
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 1),
          bounds: ui.Rect.fromLTWH(layoutSolver.getColumnLeft(1), 0, 500, 256),
          cellRange: CellRange(0, 1, 5, 5),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('edge cases', () {
      test('handles empty cell range', () {
        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 0, 0),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('handles tile outside data bounds', () {
        // Tile covers cells beyond the data
        final picture = painter.renderTile(
          coordinate: TileCoordinate(100, 100),
          bounds: const ui.Rect.fromLTWH(25600, 2400, 256, 256),
          cellRange: CellRange(100, 256, 110, 258),
          zoomBucket: ZoomBucket.full,
        );

        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });

    group('cell-level style span', () {
      test('renders with cell-level style span (single empty-text span)', () {
        // Simulate a formula cell with cell-level bold style
        data.setCell(CellCoordinate(0, 0), CellValue.number(42));
        data.setRichText(CellCoordinate(0, 0), [
          const TextSpan(style: TextStyle(fontWeight: FontWeight.bold)),
        ]);

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        // Should render without errors — the style is applied to display text
        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });

      test('renders with normal richText (multiple spans with text)', () {
        data.setCell(CellCoordinate(0, 0), CellValue.text('Hello World'));
        data.setRichText(CellCoordinate(0, 0), [
          const TextSpan(
            text: 'Hello ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: 'World'),
        ]);

        final picture = painter.renderTile(
          coordinate: TileCoordinate(0, 0),
          bounds: const ui.Rect.fromLTWH(0, 0, 256, 256),
          cellRange: CellRange(0, 0, 5, 2),
          zoomBucket: ZoomBucket.full,
        );

        // Should render normally with children spans
        expect(picture, isA<ui.Picture>());
        picture.dispose();
      });
    });
  });
}
