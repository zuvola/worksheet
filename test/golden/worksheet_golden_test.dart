@Tags(['golden'])
library;

import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

import 'golden_test_helpers.dart';

void main() {
  const Size surfaceSize = Size(700, 350);

  setUpAll(() async {
    await loadGoldenFonts();
  });

  testWidgets('worksheet screenshot', (tester) async {
    await setupGoldenSurface(tester, surfaceSize);

    // Create sample data
    final data = SparseWorksheetData(rowCount: 100, columnCount: 26);

    // Add header row
    final headers = ['Product', 'Q1', 'Q2', 'Q3', 'Q4', 'Total'];
    for (var col = 0; col < headers.length; col++) {
      data.setCell(CellCoordinate(0, col), CellValue.text(headers[col]));
      data.setStyle(
        CellCoordinate(0, col),
        const CellStyle(
          backgroundColor: Color(0xFF4472C4),
          borders: CellBorders(
            bottom: BorderStyle(
              color: Color(0xFF2E5A94),
              width: 2.0,
              lineStyle: BorderLineStyle.solid,
            ),
          ),
        ),
      );
    }

    // Add sample data rows
    final products = ['Widgets', 'Gadgets', 'Sprockets', 'Gizmos', 'Doodads'];
    for (var row = 0; row < products.length; row++) {
      data.setCell(CellCoordinate(row + 1, 0), CellValue.text(products[row]));

      // Quarterly values
      for (var q = 0; q < 4; q++) {
        final value = (row + 1) * 1000 + (q + 1) * 100 + row * 50;
        data.setCell(
            CellCoordinate(row + 1, q + 1), CellValue.number(value.toDouble()));
      }

      // Total formula display
      final total = (row + 1) * 1000 * 4 + 1000 + row * 200;
      data.setCell(CellCoordinate(row + 1, 5), CellValue.number(total.toDouble()));
      data.setRichText(
        CellCoordinate(row + 1, 5),
        [TextSpan(text: total.toDouble().toString(), style: const TextStyle(fontWeight: FontWeight.bold))],
      );
    }

    // Build widget
    await tester.pumpWidget(
      goldenWorksheetApp(data: data),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('worksheet_screenshot.png'),
    );

    await resetGoldenSurface(tester);
  });
}
