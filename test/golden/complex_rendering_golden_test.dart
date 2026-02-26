@Tags(['golden'])
library;

import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

import 'golden_test_helpers.dart';

void main() {
  setUpAll(() async {
    await loadGoldenFonts();
  });

  // -------------------------------------------------------------------------
  // 1. Merges + gridline suppression
  // -------------------------------------------------------------------------
  testWidgets('merges gridline suppression', (tester) async {
    const size = Size(700, 400);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 20, columnCount: 10);

    // 1x4 merged header spanning columns A–D
    data.setCell(CellCoordinate(0, 0), CellValue.text('Quarterly Report'));
    data.setStyle(
      CellCoordinate(0, 0),
      const CellStyle(
        backgroundColor: Color(0xFF4472C4),
        textAlignment: CellTextAlignment.center,
        borders: CellBorders(
          bottom: BorderStyle(
            color: Color(0xFF2E5A94),
            width: 2.0,
            lineStyle: BorderLineStyle.solid,
          ),
        ),
      ),
    );
    data.setRichText(CellCoordinate(0, 0), [
      const TextSpan(
        text: 'Quarterly Report',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ]);
    data.mergeCells(const CellRange(0, 0, 0, 3));

    // 2x3 merged region at rows 2–3, columns B–D
    data.setCell(CellCoordinate(2, 1), CellValue.text('Merged\nRegion'));
    data.setStyle(
      CellCoordinate(2, 1),
      const CellStyle(
        backgroundColor: Color(0xFFE2EFDA),
        textAlignment: CellTextAlignment.center,
        verticalAlignment: CellVerticalAlignment.middle,
        borders: CellBorders(
          top: BorderStyle(
            color: Color(0xFF548235),
            width: 2.0,
            lineStyle: BorderLineStyle.solid,
          ),
          bottom: BorderStyle(
            color: Color(0xFF548235),
            width: 2.0,
            lineStyle: BorderLineStyle.solid,
          ),
          left: BorderStyle(
            color: Color(0xFF548235),
            width: 2.0,
            lineStyle: BorderLineStyle.solid,
          ),
          right: BorderStyle(
            color: Color(0xFF548235),
            width: 2.0,
            lineStyle: BorderLineStyle.solid,
          ),
        ),
      ),
    );
    data.mergeCells(const CellRange(2, 1, 3, 3));

    // Adjacent cells at merge boundaries
    data.setCell(CellCoordinate(1, 0), CellValue.text('Label A'));
    data.setCell(CellCoordinate(1, 1), CellValue.text('Q1'));
    data.setCell(CellCoordinate(1, 2), CellValue.text('Q2'));
    data.setCell(CellCoordinate(1, 3), CellValue.text('Q3'));
    data.setCell(CellCoordinate(1, 4), CellValue.text('Q4'));
    data.setCell(CellCoordinate(2, 0), CellValue.number(100));
    data.setCell(CellCoordinate(3, 0), CellValue.number(200));
    data.setCell(CellCoordinate(2, 4), CellValue.number(300));
    data.setCell(CellCoordinate(3, 4), CellValue.number(400));

    // Single merged cell at row 5 spanning E–F
    data.setCell(CellCoordinate(5, 4), CellValue.text('Notes'));
    data.setStyle(
      CellCoordinate(5, 4),
      const CellStyle(
        backgroundColor: Color(0xFFFFF2CC),
        borders: CellBorders.all(
          BorderStyle(
            color: Color(0xFFBF8F00),
            lineStyle: BorderLineStyle.dashed,
          ),
        ),
      ),
    );
    data.mergeCells(const CellRange(5, 4, 5, 5));

    await tester.pumpWidget(goldenWorksheetApp(data: data, readOnly: true));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('merges_gridline_suppression.png'),
    );
    await resetGoldenSurface(tester);
  });

  // -------------------------------------------------------------------------
  // 2. Text spillover
  // -------------------------------------------------------------------------
  testWidgets('text spillover', (tester) async {
    const size = Size(700, 300);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 20, columnCount: 10);

    // Left-aligned text spilling right (col A is 90px, text is long)
    data.setCell(
      CellCoordinate(0, 0),
      CellValue.text(
        'This is a very long left-aligned text that should spill right',
      ),
    );

    // Right-aligned text spilling left
    data.setCell(
      CellCoordinate(2, 3),
      CellValue.text('Right-aligned spillover text'),
    );
    data.setStyle(
      CellCoordinate(2, 3),
      const CellStyle(textAlignment: CellTextAlignment.right),
    );

    // Center-aligned text spilling both ways
    data.setCell(
      CellCoordinate(4, 2),
      CellValue.text('Center-aligned text spilling both directions'),
    );
    data.setStyle(
      CellCoordinate(4, 2),
      const CellStyle(textAlignment: CellTextAlignment.center),
    );

    // Spillover blocked by occupied neighbor
    data.setCell(
      CellCoordinate(6, 0),
      CellValue.text('This long text will be blocked by neighbor'),
    );
    data.setCell(CellCoordinate(6, 1), CellValue.text('Blocker'));

    // Numeric overflow → ###### hash fill in narrow column
    data.setCell(CellCoordinate(1, 6), CellValue.number(123456789.99));

    await tester.pumpWidget(
      goldenWorksheetApp(
        data: data,
        readOnly: true,
        customColumnWidths: {6: 30}, // narrow column for hash fill
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('text_spillover.png'),
    );
    await resetGoldenSurface(tester);
  });

  // -------------------------------------------------------------------------
  // 3. Border styles & junctions
  // -------------------------------------------------------------------------
  testWidgets('border styles junctions', (tester) async {
    const size = Size(700, 400);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 20, columnCount: 10);

    // Solid borders
    data.setCell(CellCoordinate(0, 0), CellValue.text('Solid'));
    data.setStyle(
      CellCoordinate(0, 0),
      const CellStyle(
        borders: CellBorders.all(
          BorderStyle(lineStyle: BorderLineStyle.solid, width: 1.0),
        ),
      ),
    );

    // Dashed borders
    data.setCell(CellCoordinate(0, 2), CellValue.text('Dashed'));
    data.setStyle(
      CellCoordinate(0, 2),
      const CellStyle(
        borders: CellBorders.all(
          BorderStyle(lineStyle: BorderLineStyle.dashed, width: 1.0),
        ),
      ),
    );

    // Dotted borders
    data.setCell(CellCoordinate(0, 4), CellValue.text('Dotted'));
    data.setStyle(
      CellCoordinate(0, 4),
      const CellStyle(
        borders: CellBorders.all(
          BorderStyle(lineStyle: BorderLineStyle.dotted, width: 1.0),
        ),
      ),
    );

    // Double borders
    data.setCell(CellCoordinate(0, 6), CellValue.text('Double'));
    data.setStyle(
      CellCoordinate(0, 6),
      const CellStyle(
        borders: CellBorders.all(
          BorderStyle(lineStyle: BorderLineStyle.double, width: 1.0),
        ),
      ),
    );

    // Thick vs thin conflict resolution: thick solid should win
    data.setCell(CellCoordinate(2, 0), CellValue.text('Thick'));
    data.setStyle(
      CellCoordinate(2, 0),
      const CellStyle(
        borders: CellBorders(
          right: BorderStyle(
            lineStyle: BorderLineStyle.solid,
            width: 3.0,
            color: Color(0xFFFF0000),
          ),
        ),
      ),
    );
    data.setCell(CellCoordinate(2, 1), CellValue.text('Thin'));
    data.setStyle(
      CellCoordinate(2, 1),
      const CellStyle(
        borders: CellBorders(
          left: BorderStyle(
            lineStyle: BorderLineStyle.solid,
            width: 1.0,
            color: Color(0xFF0000FF),
          ),
        ),
      ),
    );

    // Double-border corner junction (L-shape)
    data.setCell(CellCoordinate(4, 0), CellValue.text('Corner'));
    data.setStyle(
      CellCoordinate(4, 0),
      const CellStyle(
        borders: CellBorders(
          right: BorderStyle(lineStyle: BorderLineStyle.double),
          bottom: BorderStyle(lineStyle: BorderLineStyle.double),
        ),
      ),
    );
    data.setCell(CellCoordinate(4, 1), CellValue.text('Adjacent'));
    data.setStyle(
      CellCoordinate(4, 1),
      const CellStyle(
        borders: CellBorders(
          left: BorderStyle(lineStyle: BorderLineStyle.double),
          bottom: BorderStyle(lineStyle: BorderLineStyle.double),
        ),
      ),
    );
    data.setCell(CellCoordinate(5, 0), CellValue.text('Below'));
    data.setStyle(
      CellCoordinate(5, 0),
      const CellStyle(
        borders: CellBorders(
          top: BorderStyle(lineStyle: BorderLineStyle.double),
          right: BorderStyle(lineStyle: BorderLineStyle.double),
        ),
      ),
    );

    // Mixed per-side borders on one cell
    data.setCell(CellCoordinate(4, 4), CellValue.text('Mixed'));
    data.setStyle(
      CellCoordinate(4, 4),
      const CellStyle(
        borders: CellBorders(
          top: BorderStyle(
            lineStyle: BorderLineStyle.solid,
            color: Color(0xFFFF0000),
          ),
          right: BorderStyle(
            lineStyle: BorderLineStyle.dashed,
            color: Color(0xFF00FF00),
          ),
          bottom: BorderStyle(
            lineStyle: BorderLineStyle.dotted,
            color: Color(0xFF0000FF),
          ),
          left: BorderStyle(
            lineStyle: BorderLineStyle.double,
            color: Color(0xFFFF00FF),
          ),
        ),
      ),
    );

    // T-junction: three cells meeting
    for (var col = 2; col <= 4; col++) {
      data.setCell(CellCoordinate(6, col), CellValue.text('T${col - 1}'));
      data.setStyle(
        CellCoordinate(6, col),
        const CellStyle(
          borders: CellBorders.all(
            BorderStyle(lineStyle: BorderLineStyle.double),
          ),
        ),
      );
    }

    await tester.pumpWidget(goldenWorksheetApp(data: data, readOnly: true));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('border_styles_junctions.png'),
    );
    await resetGoldenSurface(tester);
  });

  // -------------------------------------------------------------------------
  // 4. Rich text styles
  // -------------------------------------------------------------------------
  testWidgets('rich text styles', (tester) async {
    const size = Size(700, 350);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 20, columnCount: 10);

    // Multi-span rich text: bold + italic + underline + color in one cell
    data.setCell(
      CellCoordinate(0, 0),
      CellValue.text('Bold Italic Underline Color'),
    );
    data.setRichText(CellCoordinate(0, 0), [
      const TextSpan(
        text: 'Bold ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(
        text: 'Italic ',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      const TextSpan(
        text: 'Underline ',
        style: TextStyle(decoration: TextDecoration.underline),
      ),
      const TextSpan(
        text: 'Color',
        style: TextStyle(color: Color(0xFFFF0000)),
      ),
    ]);

    // Rich text with center alignment
    data.setCell(CellCoordinate(2, 1), CellValue.text('Centered Rich'));
    data.setStyle(
      CellCoordinate(2, 1),
      const CellStyle(textAlignment: CellTextAlignment.center),
    );
    data.setRichText(CellCoordinate(2, 1), [
      const TextSpan(
        text: 'Centered ',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4472C4)),
      ),
      const TextSpan(
        text: 'Rich',
        style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFED7D31)),
      ),
    ]);

    // Rich text with right alignment
    data.setCell(CellCoordinate(3, 2), CellValue.text('Right Rich'));
    data.setStyle(
      CellCoordinate(3, 2),
      const CellStyle(textAlignment: CellTextAlignment.right),
    );
    data.setRichText(CellCoordinate(3, 2), [
      const TextSpan(
        text: 'Right ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(
        text: 'Rich',
        style: TextStyle(
          decoration: TextDecoration.underline,
          color: Color(0xFF70AD47),
        ),
      ),
    ]);

    // Rich text in merged cell (2 cols wide)
    data.setCell(CellCoordinate(5, 0), CellValue.text('Merged Rich Text Cell'));
    data.setStyle(
      CellCoordinate(5, 0),
      const CellStyle(
        textAlignment: CellTextAlignment.center,
        backgroundColor: Color(0xFFFFF2CC),
      ),
    );
    data.setRichText(CellCoordinate(5, 0), [
      const TextSpan(
        text: 'Merged ',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      const TextSpan(
        text: 'Rich Text ',
        style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF4472C4)),
      ),
      const TextSpan(
        text: 'Cell',
        style: TextStyle(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF0000),
        ),
      ),
    ]);
    data.mergeCells(const CellRange(5, 0, 5, 2));

    // Format color override on rich text
    data.setCell(CellCoordinate(7, 0), CellValue.number(1234.56));
    data.setFormat(
      CellCoordinate(7, 0),
      const CellFormat(
        type: CellFormatType.number,
        formatCode: '[Red]#,##0.00',
      ),
    );

    await tester.pumpWidget(
      goldenWorksheetApp(data: data, readOnly: true, defaultColumnWidth: 100),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('rich_text_styles.png'),
    );
    await resetGoldenSurface(tester);
  });

  // -------------------------------------------------------------------------
  // 5. Wrap text + alignment
  // -------------------------------------------------------------------------
  testWidgets('wrap text alignment', (tester) async {
    const size = Size(700, 450);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 20, columnCount: 10);

    // Wrapped text with top vertical alignment in tall row
    data.setCell(
      CellCoordinate(0, 0),
      CellValue.text(
        'This is wrapped text with top vertical alignment in a tall row',
      ),
    );
    data.setStyle(
      CellCoordinate(0, 0),
      const CellStyle(
        wrapText: true,
        verticalAlignment: CellVerticalAlignment.top,
      ),
    );

    // Wrapped text with middle vertical alignment
    data.setCell(
      CellCoordinate(0, 1),
      CellValue.text('Middle aligned wrapped text content here'),
    );
    data.setStyle(
      CellCoordinate(0, 1),
      const CellStyle(
        wrapText: true,
        verticalAlignment: CellVerticalAlignment.middle,
      ),
    );

    // Wrapped text with bottom vertical alignment
    data.setCell(
      CellCoordinate(0, 2),
      CellValue.text('Bottom aligned wrapped text in tall row'),
    );
    data.setStyle(
      CellCoordinate(0, 2),
      const CellStyle(
        wrapText: true,
        verticalAlignment: CellVerticalAlignment.bottom,
      ),
    );

    // Wrapped text clipped at standard row height (row 2 is not tall)
    data.setCell(
      CellCoordinate(2, 0),
      CellValue.text(
        'This wrapped text is clipped because the row height is standard',
      ),
    );
    data.setStyle(CellCoordinate(2, 0), const CellStyle(wrapText: true));

    // Wrapped text with center horizontal alignment
    data.setCell(
      CellCoordinate(4, 0),
      CellValue.text('Center-aligned wrapped text content for testing'),
    );
    data.setStyle(
      CellCoordinate(4, 0),
      const CellStyle(
        wrapText: true,
        textAlignment: CellTextAlignment.center,
        verticalAlignment: CellVerticalAlignment.middle,
      ),
    );

    // Wrap text + rich text combo
    data.setCell(
      CellCoordinate(4, 2),
      CellValue.text('Bold and italic wrapped text here for combo test'),
    );
    data.setStyle(
      CellCoordinate(4, 2),
      const CellStyle(
        wrapText: true,
        verticalAlignment: CellVerticalAlignment.top,
      ),
    );
    data.setRichText(CellCoordinate(4, 2), [
      const TextSpan(
        text: 'Bold ',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: 'and '),
      const TextSpan(
        text: 'italic ',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      const TextSpan(text: 'wrapped text here for combo test'),
    ]);

    await tester.pumpWidget(
      goldenWorksheetApp(
        data: data,
        readOnly: true,
        customRowHeights: {0: 80, 4: 70},
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('wrap_text_alignment.png'),
    );
    await resetGoldenSurface(tester);
  });

  // -------------------------------------------------------------------------
  // 6. Format-driven styling
  // -------------------------------------------------------------------------
  testWidgets('format driven styling', (tester) async {
    const size = Size(700, 350);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 20, columnCount: 10);

    // Labels in column A
    data.setCell(CellCoordinate(0, 0), CellValue.text('Currency'));
    data.setCell(CellCoordinate(1, 0), CellValue.text('Percentage'));
    data.setCell(CellCoordinate(2, 0), CellValue.text('Date'));
    data.setCell(CellCoordinate(3, 0), CellValue.text('Scientific'));
    data.setCell(CellCoordinate(4, 0), CellValue.text('Duration'));
    data.setCell(CellCoordinate(5, 0), CellValue.text('Red neg'));
    data.setCell(CellCoordinate(6, 0), CellValue.text('Green pos'));

    // Currency format
    data.setCell(CellCoordinate(0, 1), CellValue.number(1234.56));
    data.setFormat(CellCoordinate(0, 1), CellFormat.currency);

    // Percentage format
    data.setCell(CellCoordinate(1, 1), CellValue.number(0.4275));
    data.setFormat(CellCoordinate(1, 1), CellFormat.percentageDecimal);

    // Date format
    data.setCell(CellCoordinate(2, 1), CellValue.date(DateTime(2024, 3, 15)));
    data.setFormat(CellCoordinate(2, 1), CellFormat.dateShortLong);

    // Scientific format
    data.setCell(CellCoordinate(3, 1), CellValue.number(0.00042));
    data.setFormat(CellCoordinate(3, 1), CellFormat.scientific);

    // Duration format
    data.setCell(
      CellCoordinate(4, 1),
      CellValue.duration(const Duration(hours: 2, minutes: 30, seconds: 45)),
    );
    data.setFormat(CellCoordinate(4, 1), CellFormat.duration);

    // Conditional color: [Red] for negative
    data.setCell(CellCoordinate(5, 1), CellValue.number(-500));
    data.setFormat(
      CellCoordinate(5, 1),
      const CellFormat(
        type: CellFormatType.number,
        formatCode: '#,##0;[Red]-#,##0',
      ),
    );

    // Conditional color: [Green] for positive
    data.setCell(CellCoordinate(6, 1), CellValue.number(750));
    data.setFormat(
      CellCoordinate(6, 1),
      const CellFormat(
        type: CellFormatType.number,
        formatCode: '[Green]#,##0;[Red]-#,##0',
      ),
    );

    // Implicit right-alignment for numeric types (no explicit textAlignment)
    data.setCell(CellCoordinate(0, 3), CellValue.number(42));
    data.setCell(CellCoordinate(1, 3), CellValue.number(3.14));
    data.setCell(CellCoordinate(2, 3), CellValue.text('Left'));

    await tester.pumpWidget(
      goldenWorksheetApp(data: data, readOnly: true, defaultColumnWidth: 100),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('format_driven_styling.png'),
    );
    await resetGoldenSurface(tester);
  });

  // -------------------------------------------------------------------------
  // 7. Kitchen-sink invoice
  // -------------------------------------------------------------------------
  testWidgets('invoice merges spillover borders', (tester) async {
    const size = Size(800, 500);
    await setupGoldenSurface(tester, size);

    final data = SparseWorksheetData(rowCount: 30, columnCount: 10);

    // --- Title: merged across 6 columns with double bottom border ---
    data.setCell(CellCoordinate(0, 0), CellValue.text('INVOICE'));
    data.setStyle(
      CellCoordinate(0, 0),
      const CellStyle(
        textAlignment: CellTextAlignment.center,
        verticalAlignment: CellVerticalAlignment.middle,
        backgroundColor: Color(0xFF2E5A94),
        borders: CellBorders(
          bottom: BorderStyle(
            lineStyle: BorderLineStyle.double,
            color: Color(0xFF1A3A64),
            width: 2.0,
          ),
        ),
      ),
    );
    data.setRichText(CellCoordinate(0, 0), [
      const TextSpan(
        text: 'INVOICE',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    ]);
    data.mergeCells(const CellRange(0, 0, 0, 5));

    // --- Customer name: long text that spills ---
    data.setCell(
      CellCoordinate(1, 0),
      CellValue.text('Customer: Acme Corporation International Holdings Ltd.'),
    );

    // --- Section header: merged with solid borders ---
    data.setCell(CellCoordinate(3, 0), CellValue.text('Line Items'));
    data.setStyle(
      CellCoordinate(3, 0),
      const CellStyle(
        backgroundColor: Color(0xFFD6E4F0),
        textAlignment: CellTextAlignment.center,
        borders: CellBorders(
          top: BorderStyle(lineStyle: BorderLineStyle.solid, width: 2.0),
          bottom: BorderStyle(lineStyle: BorderLineStyle.solid, width: 2.0),
        ),
      ),
    );
    data.setRichText(CellCoordinate(3, 0), [
      const TextSpan(
        text: 'Line Items',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
    data.mergeCells(const CellRange(3, 0, 3, 5));

    // --- Column headers ---
    final colHeaders = [
      'Item',
      'Description',
      'Qty',
      'Unit Price',
      'Total',
      'Notes',
    ];
    for (var col = 0; col < colHeaders.length; col++) {
      data.setCell(CellCoordinate(4, col), CellValue.text(colHeaders[col]));
      data.setStyle(
        CellCoordinate(4, col),
        const CellStyle(
          backgroundColor: Color(0xFFEEEEEE),
          borders: CellBorders(
            bottom: BorderStyle(lineStyle: BorderLineStyle.solid),
          ),
        ),
      );
      data.setRichText(CellCoordinate(4, col), [
        TextSpan(
          text: colHeaders[col],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]);
    }

    // --- Line items with currency format ---
    final items = [
      ('Widget A', 'Standard widget', 10, 25.99),
      ('Gadget B', 'Premium gadget', 5, 149.50),
      ('Sprocket C', 'Heavy-duty sprocket', 20, 8.75),
    ];
    for (var i = 0; i < items.length; i++) {
      final row = 5 + i;
      data.setCell(CellCoordinate(row, 0), CellValue.text(items[i].$1));
      data.setCell(CellCoordinate(row, 1), CellValue.text(items[i].$2));
      data.setCell(CellCoordinate(row, 2), CellValue.number(items[i].$3));
      data.setCell(CellCoordinate(row, 3), CellValue.number(items[i].$4));
      data.setFormat(CellCoordinate(row, 3), CellFormat.currency);
      final total = items[i].$3 * items[i].$4;
      data.setCell(CellCoordinate(row, 4), CellValue.number(total));
      data.setFormat(CellCoordinate(row, 4), CellFormat.currency);
    }

    // --- ###### hash fill: large number in narrow column ---
    data.setCell(CellCoordinate(5, 7), CellValue.number(9999999.99));

    // --- Grand total row ---
    data.setCell(CellCoordinate(8, 3), CellValue.text('Grand Total:'));
    data.setStyle(
      CellCoordinate(8, 3),
      const CellStyle(textAlignment: CellTextAlignment.right),
    );
    data.setRichText(CellCoordinate(8, 3), [
      const TextSpan(
        text: 'Grand Total:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);
    final grandTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.$3 * item.$4,
    );
    data.setCell(CellCoordinate(8, 4), CellValue.number(grandTotal));
    data.setFormat(CellCoordinate(8, 4), CellFormat.currency);
    data.setStyle(
      CellCoordinate(8, 4),
      const CellStyle(
        borders: CellBorders(
          top: BorderStyle(lineStyle: BorderLineStyle.double, width: 2.0),
          bottom: BorderStyle(lineStyle: BorderLineStyle.double, width: 2.0),
        ),
      ),
    );
    data.setRichText(CellCoordinate(8, 4), [
      TextSpan(
        text: CellFormat.currency.format(CellValue.number(grandTotal)),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ]);

    // --- Notes area: merged with wrap text + dashed borders ---
    data.setCell(
      CellCoordinate(10, 0),
      CellValue.text(
        'Payment due within 30 days. Please include invoice number on all correspondence. '
        'Thank you for your business!',
      ),
    );
    data.setStyle(
      CellCoordinate(10, 0),
      const CellStyle(
        wrapText: true,
        verticalAlignment: CellVerticalAlignment.top,
        backgroundColor: Color(0xFFFFF9E6),
        borders: CellBorders.all(
          BorderStyle(
            lineStyle: BorderLineStyle.dashed,
            color: Color(0xFFBF8F00),
          ),
        ),
      ),
    );
    data.mergeCells(const CellRange(10, 0, 11, 5));

    // --- Double outer border on the entire invoice area ---
    // Top-left corner cell already has double bottom from title
    // Add double border to right edge of title
    data.setStyle(
      CellCoordinate(0, 0),
      const CellStyle(
        textAlignment: CellTextAlignment.center,
        verticalAlignment: CellVerticalAlignment.middle,
        backgroundColor: Color(0xFF2E5A94),
        borders: CellBorders(
          top: BorderStyle(
            lineStyle: BorderLineStyle.double,
            color: Color(0xFF1A3A64),
            width: 2.0,
          ),
          bottom: BorderStyle(
            lineStyle: BorderLineStyle.double,
            color: Color(0xFF1A3A64),
            width: 2.0,
          ),
          left: BorderStyle(
            lineStyle: BorderLineStyle.double,
            color: Color(0xFF1A3A64),
            width: 2.0,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      goldenWorksheetApp(
        data: data,
        readOnly: true,
        defaultColumnWidth: 100,
        customColumnWidths: {7: 30}, // narrow for hash fill
        customRowHeights: {0: 40, 10: 50, 11: 50},
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('invoice_merges_spillover_borders.png'),
    );
    await resetGoldenSurface(tester);
  });
}
