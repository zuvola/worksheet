@Timeout(Duration(seconds: 30))
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  const excelRows = 1048576;
  const excelCols = 16384;

  late SparseWorksheetData data;
  late WorksheetController controller;
  final editCells = <CellCoordinate>[];
  final tapCells = <CellCoordinate>[];

  Widget buildWorksheet({bool mobileMode = false}) {
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
              rowCount: excelRows,
              columnCount: excelCols,
              mobileMode: mobileMode,
              onEditCell: (cell) => editCells.add(cell),
              onCellTap: (cell) => tapCells.add(cell),
            ),
          ),
        ),
      ),
    );
  }

  group('Jump-to-edge after column selection (desktop)', () {
    setUp(() {
      data = SparseWorksheetData(rowCount: excelRows, columnCount: excelCols);
      for (var row = 0; row <= 50000; row++) {
        for (var col = 0; col < 14; col++) {
          data.setCell(
            CellCoordinate(row, col),
            CellValue.text('R${row}C$col'),
          );
        }
      }
      controller = WorksheetController();
      editCells.clear();
      tapCells.clear();
    });

    tearDown(() {
      controller.dispose();
      data.dispose();
    });

    testWidgets(
      'double-tap on left border after column select completes < 2s',
      (tester) async {
        await tester.pumpWidget(buildWorksheet(mobileMode: false));
        await tester.pump();

        // Click column 3 header: x=400, y=12
        final hg = await tester.startGesture(
          const Offset(400.0, 12.0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 10));
        await hg.up();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          controller.selectionController.focus,
          const CellCoordinate(excelRows - 1, 3),
        );
        editCells.clear();

        // Double-tap left border of selected column
        final sw = Stopwatch()..start();
        final g1 = await tester.startGesture(
          const Offset(351.0, 108.0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 10));
        await g1.up();
        await tester.pump(const Duration(milliseconds: 50));
        final g2 = await tester.startGesture(
          const Offset(351.0, 108.0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 10));
        await g2.up();
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        sw.stop();

        final ms = sw.elapsedMilliseconds;
        final focus = controller.selectionController.focus;
        // ignore: avoid_print
        print('Left-border jump: focus=$focus, ${ms}ms, editCells=$editCells');

        expect(editCells, isEmpty, reason: 'Desktop: should jump, not edit');
        expect(focus, isNotNull);
        expect(
          ms,
          lessThan(2000),
          reason: 'Jump took ${ms}ms — freeze detected',
        );
      },
    );

    testWidgets('header edge double-tap triggers auto-fit < 2s', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet(mobileMode: false));
      await tester.pump();

      // Select column
      final hg = await tester.startGesture(
        const Offset(400.0, 12.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 10));
      await hg.up();
      await tester.pump(const Duration(milliseconds: 350));

      // Double-tap column header resize edge
      final sw = Stopwatch()..start();
      final g1 = await tester.startGesture(
        const Offset(449.0, 12.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 10));
      await g1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g2 = await tester.startGesture(
        const Offset(449.0, 12.0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 10));
      await g2.up();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      sw.stop();

      // ignore: avoid_print
      print('Auto-fit: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
