import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'dart:async';
import 'dart:developer' as developer; // For developer.log

// Reusing MockWorksheetData from other benchmarks
class MockWorksheetData implements WorksheetData {
  final int rows;
  final int cols;
  final StreamController<DataChangeEvent> _changesController;
  @override
  final MergedCellRegistry mergedCells = MergedCellRegistry();

  MockWorksheetData({this.rows = 1000, this.cols = 100})
    : _changesController = StreamController.broadcast();

  @override
  CellValue? getCell(CellCoordinate coord) {
    if (coord.row < rows && coord.column < cols) {
      return CellValue.text('R${coord.row}C${coord.column}');
    }
    return null;
  }

  @override
  CellStyle? getStyle(CellCoordinate coord) => null;

  @override
  void setCell(CellCoordinate coord, CellValue? value) {}

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {}

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) {
    final dummyBatch = _MockWorksheetDataBatch();
    updates(dummyBatch);
    notifyListeners();
  }

  @override
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) async {
    final dummyBatch = _MockWorksheetDataBatch();
    await updates(dummyBatch);
    notifyListeners();
  }

  @override
  Stream<DataChangeEvent> get changes => _changesController.stream;

  @override
  int get rowCount => rows;

  @override
  int get columnCount => cols;

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) => const [];

  @override
  void clearRange(CellRange range) {}

  @override
  CellRange? smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) => null;

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {}

  @override
  void mergeCells(CellRange range) {}

  @override
  void unmergeCells(CellCoordinate cell) {}

  @override
  void dispose() {
    _changesController.close();
  }

  @override
  CellFormat? getFormat(CellCoordinate coord) => null;
  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {}
  @override
  List<TextSpan>? getRichText(CellCoordinate coord) => null;
  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}
  @override
  bool hasValue(CellCoordinate coord) => getCell(coord) != null;
  @override
  void clearRichTextInRange(CellRange range) {}
  @override
  Iterable<MapEntry<CellCoordinate, List<TextSpan>>> getRichTextInRange(
    CellRange range,
  ) => const [];
  @override
  Iterable<MapEntry<CellCoordinate, CellStyle>> getStylesInRange(
    CellRange range,
  ) => const [];
  @override
  Iterable<MapEntry<CellCoordinate, CellFormat>> getFormatsInRange(
    CellRange range,
  ) => const [];
  @override
  void unmergeCellsInRange(CellRange range) {}
  @override
  void moveMerges(CellRange source, CellCoordinate destination) {}
  @override
  void replicateMerges({
    required CellRange sourceRange,
    required CellRange targetRange,
    required bool vertical,
  }) {}
  @override
  int? findNextPopulatedRow(int column, int fromRow) => null;
  @override
  int? findPrevPopulatedRow(int column, int fromRow) => null;
  @override
  int? findNextPopulatedColumn(int row, int fromColumn) => null;
  @override
  int? findPrevPopulatedColumn(int row, int fromColumn) => null;
  bool get hasFormulas => false;
  bool get hasRichText => false;
  bool get hasMergedCells => false;
  bool get hasStyles => false;
  List<CellCoordinate> get allCellsWithData => [];
  Map<CellCoordinate, CellStyle> get allStyles => {};
  List<CellRange> get allMergedCells => [];
  CellValue? getFormula(CellCoordinate coord) => null;
  Cell? getRawCell(CellCoordinate coord) => null;
  bool hasFormula(CellCoordinate coord) => false;
  bool hasRichTextAt(CellCoordinate coord) => false;
  bool hasStyle(CellCoordinate coord) => false;
  bool hasFormat(CellCoordinate coord) => false;
  void clearFormat(CellCoordinate coord) {}
  void clearStyle(CellCoordinate coord) {}

  void notifyListeners() {
    _changesController.add(DataChangeEvent.reset());
  }
}

// Dummy implementation for WorksheetDataBatch for the mock
class _MockWorksheetDataBatch implements WorksheetDataBatch {
  @override
  void clearRange(CellRange range) {}

  @override
  void clearFormats(CellRange range) {}

  @override
  void clearStyles(CellRange range) {}

  @override
  void clearValues(CellRange range) {}

  @override
  void copyRange(CellRange source, CellCoordinate destination) {}

  @override
  void fillRangeWithCell(CellRange range, Cell? value) {}

  @override
  void setCell(CellCoordinate coord, CellValue? value) {}

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {}

  @override
  void setRichText(CellCoordinate coord, List<TextSpan>? richText) {}

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {}
}

void main() {
  group('Interaction Benchmarks', () {
    Future<void> measureInteraction(
      WidgetTester tester,
      String description,
      Future<void> Function(
        WorksheetController controller,
        EditController editController,
      )
      action, {
      int rows = 100,
      int cols = 20,
    }) async {
      final WorksheetController controller = WorksheetController();
      final EditController editController =
          EditController(); // Instantiate EditController
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Worksheet(
              data: MockWorksheetData(rows: rows, cols: cols),
              controller: controller,
              editController: editController, // Pass EditController
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Stopwatch stopwatch = Stopwatch()..start();
      await action(controller, editController); // Pass editController to action
      stopwatch.stop();

      developer.log(
        '$description latency: ${stopwatch.elapsedMicroseconds / 1000} ms',
        name: 'Interaction_Benchmark',
      );
    }

    testWidgets('Typing in a cell latency', (WidgetTester tester) async {
      await measureInteraction(
        tester,
        'Typing in a cell',
        (controller, editController) async {
          // Receive editController
          final cell = CellCoordinate(0, 0);
          controller.selectionController.selectCell(cell);
          await tester.pumpAndSettle();

          // Use EditController to start edit
          editController.startEdit(
            cell: cell,
            initialText: '',
            trigger: EditTrigger.programmatic,
          ); // Corrected EditTrigger
          await tester.pumpAndSettle();

          // Simulate typing a character
          await tester.enterText(
            find.byType(EditableText),
            'A',
          ); // Now EditableText should be found
          await tester.pumpAndSettle();
        },
        rows: 10,
        cols: 5,
      );
      // Basic verification that a widget exists
      expect(find.byType(Worksheet), findsOneWidget);
    });

    testWidgets('Resizing a column latency', (WidgetTester tester) async {
      await measureInteraction(
        tester,
        'Resizing a column',
        (controller, editController) async {
          // Receive editController, though not used here
          // Find the worksheet widget
          final Finder worksheetFinder = find.byType(Worksheet);
          expect(worksheetFinder, findsOneWidget);

          // Get the context of the worksheet to access layout solver and theme
          final BuildContext context = tester.element(worksheetFinder);
          final WorksheetThemeData theme = WorksheetTheme.of(context);
          final LayoutSolver layoutSolver = controller.layoutSolver!;

          // Assuming default header width and height
          final double headerHeight = theme.columnHeaderHeight;
          final double headerWidth = theme.rowHeaderWidth;

          // Target the resize handle for column 1 (just after the first column header)
          // Adjust coordinates to be relative to the widget's top-left corner
          final RenderBox renderBox = tester.renderObject(worksheetFinder);
          final Offset worksheetTopLeft = renderBox.localToGlobal(Offset.zero);

          final Offset resizeHandleStart =
              worksheetTopLeft +
              Offset(
                headerWidth +
                    layoutSolver.getColumnWidth(0) * controller.zoom -
                    2, // 2 pixels to the left of the actual divider
                headerHeight / 2,
              );

          // Perform a drag gesture to resize the column
          final TestGesture gesture = await tester.startGesture(
            resizeHandleStart,
          );
          await tester.pump(); // Start the gesture

          await gesture.moveBy(
            const Offset(20, 0),
          ); // Drag 20 pixels to the right
          await tester
              .pumpAndSettle(); // Wait for layout and rendering to settle

          await gesture.up(); // End the gesture
          await tester.pumpAndSettle();
        },
        rows: 10,
        cols: 5,
      );
      expect(find.byType(Worksheet), findsOneWidget);
    });

    testWidgets(
      'Copy-Paste of a large range latency',
      timeout: const Timeout(Duration(seconds: 30)),
      (WidgetTester tester) async {
        final controller = WorksheetController();
        final editController = EditController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Worksheet(
                data: MockWorksheetData(rows: 10, cols: 5),
                controller: controller,
                editController: editController,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        _installMockClipboard();
        addTearDown(_removeMockClipboard);

        final stopwatch = Stopwatch()..start();

        // Select a 5-row x 3-column range.
        controller.selectionController.selectRange(const CellRange(0, 0, 4, 2));
        await tester.pump();

        // Copy (Ctrl+C).
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        // Pump twice to flush the async clipboard write (timers are faked).
        await tester.pump();
        await tester.pump();

        // Move selection to a non-overlapping destination.
        controller.selectionController.selectCell(const CellCoordinate(6, 0));
        await tester.pump();

        // Paste (Ctrl+V).
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        // Pump twice to flush the async clipboard read + batch update.
        await tester.pump();
        await tester.pump();

        stopwatch.stop();
        developer.log(
          'Copy-Paste large range latency: ${stopwatch.elapsedMicroseconds / 1000} ms',
          name: 'Interaction_Benchmark',
        );

        expect(find.byType(Worksheet), findsOneWidget);
      },
    );
  });
}

String? _mockClipboardText;

void _installMockClipboard({String? initialText}) {
  _mockClipboardText = initialText;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          _mockClipboardText = args['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          if (_mockClipboardText == null) return null;
          return <String, dynamic>{'text': _mockClipboardText};
        }
        return null;
      });
}

void _removeMockClipboard() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
}
