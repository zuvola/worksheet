import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_format.dart';
import 'package:worksheet/src/core/models/cell_range.dart';
import 'package:worksheet/src/core/models/cell_style.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  late SparseWorksheetData data;
  late WorksheetController controller;

  // Default theme values for reference:
  // rowHeaderWidth = 50, columnHeaderHeight = 24, defaultRowHeight = 24, defaultColumnWidth = 100

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    controller = WorksheetController();
  });

  tearDown(() {
    controller.dispose();
    data.dispose();
  });

  Widget buildWorksheet({
    OnResizeColumnCallback? onResizeColumn,
    OnResizeRowCallback? onResizeRow,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: SizedBox(
            width: 800,
            height: 600,
            child: Worksheet(
              data: data,
              controller: controller,
              rowCount: 100,
              columnCount: 26,
              onResizeColumn: onResizeColumn,
              onResizeRow: onResizeRow,
            ),
          ),
        ),
      ),
    );
  }

  /// Simulates a double-tap via GestureDetector.
  Future<void> doubleTapAt(WidgetTester tester, Offset globalPosition) async {
    await tester.tapAt(globalPosition);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(globalPosition);
    await tester.pumpAndSettle();
  }

  group('Auto-fit column via double-click', () {
    testWidgets('auto-fit column adjusts width to match longest content', (
      tester,
    ) async {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('Short'));
      data.setCell(
        const CellCoordinate(1, 0),
        CellValue.text('A much longer text'),
      );
      data.setCell(const CellCoordinate(2, 0), CellValue.text('Med'));

      double? resizedWidth;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            if (column == 0) resizedWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      // Column 0 right edge: headerWidth + colWidth = 50 + 100 = 150
      // Column header area: y < headerHeight (24)
      // Position near column boundary, within 4px tolerance
      await doubleTapAt(tester, const Offset(149.0, 12.0));

      expect(resizedWidth, isNotNull);
      expect(resizedWidth, greaterThan(20.0));
    });

    testWidgets('auto-fit with empty column sets minimum width', (
      tester,
    ) async {
      double? resizedWidth;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            if (column == 0) resizedWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      await doubleTapAt(tester, const Offset(149.0, 12.0));

      expect(resizedWidth, isNotNull);
      expect(resizedWidth, equals(20.0));
    });

    testWidgets('auto-fit column 2 adjusts to correct width', (tester) async {
      data.setCell(const CellCoordinate(0, 2), CellValue.text('Hello World'));

      double? resizedWidth;
      int? resizedColumn;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            resizedColumn = column;
            resizedWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      // Column 2 right edge: headerWidth + 3*colWidth = 50 + 300 = 350
      await doubleTapAt(tester, const Offset(349.0, 12.0));

      expect(resizedColumn, equals(2));
      expect(resizedWidth, isNotNull);
      expect(resizedWidth, greaterThan(20.0));
    });

    testWidgets(
      'auto-fit does not fire spurious resize for other selected columns',
      (tester) async {
        data.setCell(const CellCoordinate(0, 0), CellValue.text('Short'));

        // Track ALL resize callbacks — column index and width
        final resizes = <(int, double)>[];
        await tester.pumpWidget(
          buildWorksheet(
            onResizeColumn: (column, newWidth) {
              resizes.add((column, newWidth));
            },
          ),
        );
        await tester.pump();

        // Select columns 0-2 (full-column selection would include col 0)
        // First select a cell to establish a focus
        await tester.tapAt(const Offset(100, 40));
        await tester.pumpAndSettle();

        // Now double-click on column 0 right edge to auto-fit
        await doubleTapAt(tester, const Offset(149.0, 12.0));

        // Only column 0 should have been resized (auto-fit)
        // No spurious resize of other columns
        expect(resizes.length, equals(1));
        expect(resizes[0].$1, equals(0));
      },
    );

    testWidgets('auto-fit does not select column after layout change', (
      tester,
    ) async {
      // Regression: GestureDetector.onDoubleTapDown fires before
      // Listener.onPointerDown. Auto-fit changes the column width, so
      // the Listener's hit-test at the original position resolves to
      // columnHeader instead of columnResizeHandle → selects entire column.
      data.setCell(const CellCoordinate(0, 0), CellValue.text('Short'));

      await tester.pumpWidget(
        buildWorksheet(onResizeColumn: (column, newWidth) {}),
      );
      await tester.pump();

      // Select cell (5, 5) to establish a known selection state
      final selectionController = controller.selectionController;
      selectionController.selectCell(const CellCoordinate(5, 5));
      await tester.pump();

      final selectionBefore = selectionController.selectedRange;

      // Double-click on column 0 right edge → should auto-fit only,
      // not select a column
      await doubleTapAt(tester, const Offset(149.0, 12.0));

      // Selection must not have changed to a full-column selection
      final selectionAfter = selectionController.selectedRange;
      // Should still be the same single cell
      expect(selectionAfter, equals(selectionBefore));
      // Definitely should NOT be a full-column selection
      expect(selectionAfter, isNot(equals(CellRange(0, 1, 99, 1))));
    });

    testWidgets('auto-fit does not change scroll position', (tester) async {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('Short'));

      await tester.pumpWidget(buildWorksheet());
      await tester.pump();

      final scrollXBefore = controller.scrollX;
      final scrollYBefore = controller.scrollY;

      // Double-click on column 0 right edge
      await doubleTapAt(tester, const Offset(149.0, 12.0));

      expect(controller.scrollX, equals(scrollXBefore));
      expect(controller.scrollY, equals(scrollYBefore));
    });
  });

  group('Auto-fit row via double-click', () {
    testWidgets('auto-fit row adjusts height to match tallest content', (
      tester,
    ) async {
      data.setCell(const CellCoordinate(0, 0), CellValue.text('Text'));
      data.setCell(const CellCoordinate(0, 1), CellValue.text('Another'));

      double? resizedHeight;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeRow: (row, newHeight) {
            if (row == 0) resizedHeight = newHeight;
          },
        ),
      );
      await tester.pump();

      // Row 0 bottom edge: headerHeight + rowHeight = 24 + 24 = 48
      // Row header area: x < headerWidth (50)
      // Position near row boundary, within 4px tolerance
      await doubleTapAt(tester, const Offset(25.0, 47.0));

      expect(resizedHeight, isNotNull);
      expect(resizedHeight, greaterThan(10.0));
    });

    testWidgets(
      'auto-fit row without wrapText uses single-line height for long text',
      (tester) async {
        // Long text that would wrap if constrained to column width
        final longText = 'A' * 200;
        data.setCell(const CellCoordinate(0, 0), CellValue.text(longText));
        // wrapText defaults to false — no explicit style needed

        double? resizedHeight;
        await tester.pumpWidget(
          buildWorksheet(
            onResizeRow: (row, newHeight) {
              if (row == 0) resizedHeight = newHeight;
            },
          ),
        );
        await tester.pump();

        await doubleTapAt(tester, const Offset(25.0, 47.0));

        expect(resizedHeight, isNotNull);
        // Single-line height: fontSize(14) + 2*cellPadding(4) ≈ 22,
        // clamped to min 10. Should be well under 30.
        expect(resizedHeight!, lessThan(30.0));
      },
    );

    testWidgets('auto-fit row with wrapText uses wrapped height', (
      tester,
    ) async {
      // Long text that will wrap when constrained to column width
      final longText = 'A' * 200;
      data.setCell(const CellCoordinate(0, 0), CellValue.text(longText));
      data.setStyle(
        const CellCoordinate(0, 0),
        const CellStyle(wrapText: true),
      );

      double? resizedHeight;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeRow: (row, newHeight) {
            if (row == 0) resizedHeight = newHeight;
          },
        ),
      );
      await tester.pump();

      await doubleTapAt(tester, const Offset(25.0, 47.0));

      expect(resizedHeight, isNotNull);
      // Wrapped text in a 100px column should be much taller than single line
      expect(resizedHeight!, greaterThan(30.0));
    });
  });

  group('Auto-fit with merged cells', () {
    testWidgets('auto-fit anchor column considers merged cell content', (
      tester,
    ) async {
      // Merge (0,0)–(0,2), set wide text on anchor (0,0)
      data.mergeCells(const CellRange(0, 0, 0, 2));
      data.setCell(
        const CellCoordinate(0, 0),
        CellValue.text(
          'This is a very long merged cell text that spans columns',
        ),
      );

      double? resizedWidth;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            if (column == 0) resizedWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      // Double-click on column 0 right edge
      await doubleTapAt(tester, const Offset(149.0, 12.0));

      expect(resizedWidth, isNotNull);
      // Merged content was measured; after subtracting other columns'
      // widths, the remainder for column 0 should exceed the minimum.
      expect(resizedWidth, greaterThan(20.0));
    });

    testWidgets('auto-fit non-anchor column picks up merged content', (
      tester,
    ) async {
      // Merge (0,0)–(0,2), set wide text on anchor (0,0)
      data.mergeCells(const CellRange(0, 0, 0, 2));
      data.setCell(
        const CellCoordinate(0, 0),
        CellValue.text(
          'This is a very long merged cell text that spans columns',
        ),
      );

      double? resizedWidth;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            if (column == 1) resizedWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      // Column 1 right edge: headerWidth + 2*colWidth = 50 + 200 = 250
      await doubleTapAt(tester, const Offset(249.0, 12.0));

      expect(resizedWidth, isNotNull);
      // Non-anchor column should pick up merged content and get > minimum
      expect(resizedWidth, greaterThan(20.0));
    });

    testWidgets('auto-fit row considers merged cell spanning multiple rows', (
      tester,
    ) async {
      // Merge (0,0)–(2,0), set long wrapping text on anchor
      data.mergeCells(const CellRange(0, 0, 2, 0));
      data.setCell(
        const CellCoordinate(0, 0),
        CellValue.text('A' * 200),
      ); // long text
      data.setStyle(
        const CellCoordinate(0, 0),
        const CellStyle(wrapText: true),
      );

      double? resizedHeight;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeRow: (row, newHeight) {
            if (row == 1) resizedHeight = newHeight;
          },
        ),
      );
      await tester.pump();

      // Row 1 bottom edge: headerHeight + 2*rowHeight = 24 + 48 = 72
      await doubleTapAt(tester, const Offset(25.0, 71.0));

      expect(resizedHeight, isNotNull);
      // Non-anchor row should pick up merged content height
      expect(resizedHeight, greaterThan(10.0));
    });

    testWidgets(
      'merged cell content fits in other columns — no extra width needed',
      (tester) async {
        // Merge (0,0)–(0,2), set short text that easily fits in other columns
        data.mergeCells(const CellRange(0, 0, 0, 2));
        data.setCell(const CellCoordinate(0, 0), CellValue.text('Hi'));

        double? resizedWidth;
        await tester.pumpWidget(
          buildWorksheet(
            onResizeColumn: (column, newWidth) {
              if (column == 1) resizedWidth = newWidth;
            },
          ),
        );
        await tester.pump();

        // Column 1 right edge: headerWidth + 2*colWidth = 50 + 200 = 250
        await doubleTapAt(tester, const Offset(249.0, 12.0));

        expect(resizedWidth, isNotNull);
        // Short text "Hi" fits within other columns' widths, so column 1
        // needs only the minimum.
        expect(resizedWidth, equals(20.0));
      },
    );
  });

  group('Auto-fit with cell-level rich text styles', () {
    testWidgets('cell-level large font style affects column width', (
      tester,
    ) async {
      // Set text with cell-level large font via setRichText
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.text('Hello World'));

      // Also set the same text without style in column 1 for comparison
      const coordPlain = CellCoordinate(0, 1);
      data.setCell(coordPlain, CellValue.text('Hello World'));

      // Apply cell-level large font (single empty TextSpan with fontSize)
      // Test font varies by size, not by weight
      data.setRichText(coord, [
        const TextSpan(style: TextStyle(fontSize: 28.0)),
      ]);

      double? styledWidth;
      double? plainWidth;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            if (column == 0) styledWidth = newWidth;
            if (column == 1) plainWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      // Auto-fit column 0 (large font)
      await doubleTapAt(tester, const Offset(149.0, 12.0));
      await tester.pump();

      // Column 1 right edge after column 0 resize: headerWidth + col0Width + col1Width
      final col1RightEdge = 50.0 + styledWidth! + 100.0;
      await doubleTapAt(tester, Offset(col1RightEdge - 1.0, 12.0));

      expect(styledWidth, isNotNull);
      expect(plainWidth, isNotNull);
      // Large font text should be wider than default font text
      expect(styledWidth!, greaterThan(plainWidth!));
    });

    testWidgets('cell-level large font style affects row height', (
      tester,
    ) async {
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.text('Tall'));

      // Apply cell-level large font size (single empty TextSpan with large font)
      data.setRichText(coord, [
        const TextSpan(style: TextStyle(fontSize: 36.0)),
      ]);

      double? resizedHeight;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeRow: (row, newHeight) {
            if (row == 0) resizedHeight = newHeight;
          },
        ),
      );
      await tester.pump();

      // Row 0 bottom edge: headerHeight + rowHeight = 24 + 24 = 48
      await doubleTapAt(tester, const Offset(25.0, 47.0));

      expect(resizedHeight, isNotNull);
      // Default font is 14px, cell-level style is 36px — row should be much taller
      // Default single-line height: ~14px + padding ≈ 22px
      // With 36px font: ~36px + padding ≈ 44px+
      expect(resizedHeight!, greaterThan(30.0));
    });
  });

  group('Auto-fit with CellFormat', () {
    testWidgets('currency format affects column width', (tester) async {
      // Set a number with currency format — "$1,000.00" is wider than "1000.0"
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.number(1000));
      data.setFormat(coord, CellFormat.currency);

      // Column 1 has same number without format for comparison
      const coordPlain = CellCoordinate(0, 1);
      data.setCell(coordPlain, CellValue.number(1000));

      double? formattedWidth;
      double? plainWidth;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeColumn: (column, newWidth) {
            if (column == 0) formattedWidth = newWidth;
            if (column == 1) plainWidth = newWidth;
          },
        ),
      );
      await tester.pump();

      // Auto-fit column 0 (formatted)
      await doubleTapAt(tester, const Offset(149.0, 12.0));
      await tester.pump();

      // Auto-fit column 1 (plain) — recalculate right edge after col 0 resize
      final col1RightEdge = 50.0 + formattedWidth! + 100.0;
      await doubleTapAt(tester, Offset(col1RightEdge - 1.0, 12.0));

      expect(formattedWidth, isNotNull);
      expect(plainWidth, isNotNull);
      // "$1,000.00" should be wider than "1000.0"
      expect(formattedWidth!, greaterThan(plainWidth!));
    });

    testWidgets('formatted text with wrapText affects row height', (
      tester,
    ) async {
      // Use a long formatted text that will wrap
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.number(123456789.12));
      // Accounting format with long text representation
      data.setFormat(
        coord,
        const CellFormat(
          type: CellFormatType.currency,
          formatCode: r'$#,##0.00',
        ),
      );
      data.setStyle(coord, const CellStyle(wrapText: true));

      // Shrink column to force wrapping of "$123,456,789.12"
      // We can't set column width directly in the test, but the default
      // 100px column should cause the formatted text to wrap

      double? resizedHeight;
      await tester.pumpWidget(
        buildWorksheet(
          onResizeRow: (row, newHeight) {
            if (row == 0) resizedHeight = newHeight;
          },
        ),
      );
      await tester.pump();

      // Row 0 bottom edge: headerHeight + rowHeight = 24 + 24 = 48
      await doubleTapAt(tester, const Offset(25.0, 47.0));

      expect(resizedHeight, isNotNull);
      // Height should reflect the formatted text, not just the raw number
      expect(resizedHeight!, greaterThan(10.0));
    });
  });
}
