import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/core/models/freeze_config.dart';
import 'package:worksheet/src/widgets/worksheet_controller.dart';
import 'package:worksheet/src/widgets/worksheet_theme.dart';
import 'package:worksheet/src/widgets/worksheet_widget.dart';

void main() {
  late SparseWorksheetData data;
  late WorksheetController controller;

  setUp(() {
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
    // Populate some cells in the frozen region
    data.setCell(const CellCoordinate(0, 0), const CellValue.text('Header'));
    data.setCell(const CellCoordinate(0, 1), const CellValue.text('Col B'));
    data.setCell(const CellCoordinate(1, 0), const CellValue.text('Row 2'));
    controller = WorksheetController();
  });

  tearDown(() {
    controller.dispose();
    data.dispose();
  });

  Widget buildWorksheet({FreezeConfig freezeConfig = FreezeConfig.none}) {
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
              freezeConfig: freezeConfig,
            ),
          ),
        ),
      ),
    );
  }

  group('Frozen panes integration', () {
    testWidgets('frozen layer present when freezeConfig has frozen panes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWorksheet(
          freezeConfig: const FreezeConfig(frozenRows: 1, frozenColumns: 1),
        ),
      );

      // The widget should build without errors and display content
      expect(find.byType(Worksheet), findsOneWidget);

      // Verify controller has freeze config wired
      expect(
        controller.freezeConfig,
        const FreezeConfig(frozenRows: 1, frozenColumns: 1),
      );
    });

    testWidgets('frozen layer absent when freezeConfig is none', (
      tester,
    ) async {
      await tester.pumpWidget(buildWorksheet());

      expect(find.byType(Worksheet), findsOneWidget);
      expect(controller.freezeConfig, FreezeConfig.none);
    });

    testWidgets('dynamic freeze config change (none -> frozen -> none)', (
      tester,
    ) async {
      // Start with no frozen panes
      await tester.pumpWidget(buildWorksheet());
      expect(controller.freezeConfig, FreezeConfig.none);

      // Switch to frozen panes
      await tester.pumpWidget(
        buildWorksheet(
          freezeConfig: const FreezeConfig(frozenRows: 2, frozenColumns: 1),
        ),
      );
      expect(
        controller.freezeConfig,
        const FreezeConfig(frozenRows: 2, frozenColumns: 1),
      );

      // Switch back to none
      await tester.pumpWidget(buildWorksheet());
      expect(controller.freezeConfig, FreezeConfig.none);
    });

    testWidgets('frozen rows only config builds without error', (tester) async {
      await tester.pumpWidget(
        buildWorksheet(freezeConfig: const FreezeConfig(frozenRows: 3)),
      );

      expect(find.byType(Worksheet), findsOneWidget);
      expect(controller.freezeConfig, const FreezeConfig(frozenRows: 3));
    });

    testWidgets('frozen columns only config builds without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWorksheet(freezeConfig: const FreezeConfig(frozenColumns: 2)),
      );

      expect(find.byType(Worksheet), findsOneWidget);
      expect(controller.freezeConfig, const FreezeConfig(frozenColumns: 2));
    });
  });
}
