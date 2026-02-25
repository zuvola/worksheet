# Testing Guide

Testing patterns and examples for the worksheet widget.

## Table of Contents

1. [Unit Testing Core Components](#unit-testing-core-components)
2. [Widget Testing](#widget-testing)
3. [Mocking WorksheetData](#mocking-worksheetdata)
4. [Simulating Pointer Gestures](#simulating-pointer-gestures)
5. [Testing Selection Behavior](#testing-selection-behavior)
6. [Performance Benchmarks](#performance-benchmarks)
    * [Memory Benchmarks](#memory-benchmarks)
    * [Startup (TTFR) Benchmarks](#startup-ttfr-benchmarks)
    * [Interaction Benchmarks](#interaction-benchmarks)
7. [Interpreting Benchmark Results & CI/CD Integration](#interpreting-benchmark-results--cicd-integration)
8. [Running Tests](#running-tests)

---

## Unit Testing Core Components

### Testing SpanList

`SpanList` manages row/column dimensions with O(log n) lookups:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  group('SpanList', () {
    test('default size for all indices', () {
      final spans = SpanList(count: 100, defaultSize: 24.0);

      expect(spans.count, 100);
      expect(spans.sizeAt(0), 24.0);
      expect(spans.sizeAt(50), 24.0);
      expect(spans.sizeAt(99), 24.0);
    });

    test('custom sizes override defaults', () {
      final spans = SpanList(
        count: 100,
        defaultSize: 24.0,
        customSizes: {5: 48.0, 10: 100.0},
      );

      expect(spans.sizeAt(4), 24.0);
      expect(spans.sizeAt(5), 48.0);
      expect(spans.sizeAt(10), 100.0);
    });

    test('positionAt returns cumulative offset', () {
      final spans = SpanList(count: 10, defaultSize: 24.0);

      expect(spans.positionAt(0), 0.0);
      expect(spans.positionAt(1), 24.0);
      expect(spans.positionAt(5), 120.0);  // 5 * 24
    });

    test('positionAt with custom sizes', () {
      final spans = SpanList(
        count: 10,
        defaultSize: 24.0,
        customSizes: {2: 48.0},  // Row 2 is double height
      );

      expect(spans.positionAt(0), 0.0);
      expect(spans.positionAt(1), 24.0);
      expect(spans.positionAt(2), 48.0);   // 24 + 24
      expect(spans.positionAt(3), 96.0);   // 24 + 24 + 48
      expect(spans.positionAt(4), 120.0);  // 24 + 24 + 48 + 24
    });

    test('indexAtPosition finds correct index via binary search', () {
      final spans = SpanList(count: 1000, defaultSize: 24.0);

      expect(spans.indexAtPosition(0.0), 0);
      expect(spans.indexAtPosition(23.9), 0);
      expect(spans.indexAtPosition(24.0), 1);
      expect(spans.indexAtPosition(100.0), 4);  // 100 / 24 = 4.16
    });

    test('indexAtPosition clamps to valid range', () => {
      final spans = SpanList(count: 100, defaultSize: 24.0);

      expect(spans.indexAtPosition(-10.0), 0);  // Clamp to first
      expect(spans.indexAtPosition(10000.0), 99);  // Clamp to last
    });

    test('totalSize calculates sum of all sizes', () => {
      final spans = SpanList(count: 10, defaultSize: 24.0);
      expect(spans.totalSize, 240.0);  // 10 * 24

      final customSpans = SpanList(
        count: 10,
        defaultSize: 24.0,
        customSizes: {0: 48.0, 9: 100.0},
      );
      // (48) + (8 * 24) + (100) = 340
      expect(customSpans.totalSize, 340.0);
    });

    test('setSize updates size and recalculates cumulative', () => {
      final spans = SpanList(count: 10, defaultSize: 24.0);

      spans.setSize(5, 48.0);

      expect(spans.sizeAt(5), 48.0);
      expect(spans.positionAt(6), 24.0 * 5 + 48.0);  // 168
    });

    test('getVisibleRange returns indices in viewport', () => {
      final spans = SpanList(count: 1000, defaultSize: 24.0);

      final range = spans.getVisibleRange(scrollOffset: 100.0, viewportSize: 200.0);

      // At scroll 100, first visible row is 100/24 = 4
      // Viewport shows 200/24 ≈ 8 rows
      expect(range.startIndex, 4);
      expect(range.endIndex, 12);  // 4 + 8
    });
  });
}
```

### Testing LayoutSolver

`LayoutSolver` combines row and column `SpanList`s for cell geometry:

```dart
void main() {
  group('LayoutSolver', () {
    late LayoutSolver solver;

    setUp(() {
      solver = LayoutSolver(
        rows: SpanList(count: 100, defaultSize: 24.0),
        columns: SpanList(count: 26, defaultSize: 100.0),
      );
    });

    test('getCellBounds returns correct rectangle', () => {
      final bounds = solver.getCellBounds(const CellCoordinate(5, 3));

      expect(bounds.left, 300.0);   // 3 columns * 100
      expect(bounds.top, 120.0);    // 5 rows * 24
      expect(bounds.width, 100.0);  // Column width
      expect(bounds.height, 24.0);  // Row height
    });

    test('getCellAt finds cell from position', () => {
      final cell = solver.getCellAt(const Offset(350.0, 130.0));

      expect(cell.row, 5);     // 130 / 24 = 5.4 → 5
      expect(cell.column, 3);  // 350 / 100 = 3.5 → 3
    });

    test('getVisibleRows returns range in viewport', () => {
      final range = solver.getVisibleRows(100.0, 200.0);

      expect(range.startIndex, 4);   // 100 / 24 = 4.16
      expect(range.endIndex, 12);    // (100 + 200) / 24 = 12.5
    });

    test('getVisibleColumns returns range in viewport', () => {
      final range = solver.getVisibleColumns(250.0, 400.0);

      expect(range.startIndex, 2);   // 250 / 100 = 2.5
      expect(range.endIndex, 6);     // (250 + 400) / 100 = 6.5
    });

    test('setRowHeight updates layout', () => {
      solver.setRowHeight(5, 48.0);

      expect(solver.getRowHeight(5), 48.0);
      expect(solver.getRowTop(6), 24.0 * 5 + 48.0);
    });

    test('setColumnWidth updates layout', () => {
      solver.setColumnWidth(3, 150.0);

      expect(solver.getColumnWidth(3), 150.0);
      expect(solver.getColumnLeft(4), 100.0 * 3 + 150.0);
    });

    test('getRangeBounds calculates bounding rect', () => {
      final bounds = solver.getRangeBounds(
        startRow: 2,
        startColumn: 1,
        endRow: 4,
        endColumn: 3,
      );

      expect(bounds.left, 100.0);    // Column 1 * 100
      expect(bounds.top, 48.0);      // Row 2 * 24
      expect(bounds.width, 300.0);   // 3 columns * 100
      expect(bounds.height, 72.0);   // 3 rows * 24
    });
  });
}
```

### Testing CellCoordinate

```dart
void main() {
  group('CellCoordinate', () {
    test('creates coordinate from row and column', () {
      const coord = CellCoordinate(5, 3);
      expect(coord.row, 5);
      expect(coord.column, 3);
    });

    test('toNotation converts to Excel-style', () {
      expect(const CellCoordinate(0, 0).toNotation(), 'A1');
      expect(const CellCoordinate(0, 25).toNotation(), 'Z1');
      expect(const CellCoordinate(0, 26).toNotation(), 'AA1');
      expect(const CellCoordinate(99, 27).toNotation(), 'AB100');
    });

    test('equality comparison', () {
      const a = CellCoordinate(5, 3);
      const b = CellCoordinate(5, 3);
      const c = CellCoordinate(5, 4);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode consistency', () => {
      const a = CellCoordinate(5, 3);
      const b = CellCoordinate(5, 3);

      expect(a.hashCode, b.hashCode);
    });

    test('copyWith creates modified copy', () => {
      const original = CellCoordinate(5, 3);

      expect(original.copyWith(row: 10), const CellCoordinate(10, 3));
      expect(original.copyWith(column: 7), const CellCoordinate(5, 7));
      expect(original.copyWith(row: 10, column: 7), const CellCoordinate(10, 7));
    });
  });
}
```

### Testing CellRange

```dart
void main() {
  group('CellRange', () => {
    test('creates range from corners', () {
      const range = CellRange(2, 1, 5, 4);

      expect(range.startRow, 2);
      expect(range.startColumn, 1);
      expect(range.endRow, 5);
      expect(range.endColumn, 4);
    });

    test('single cell range', () => {
      const range = CellRange.single(CellCoordinate(3, 2));

      expect(range.startRow, 3);
      expect(range.startColumn, 2);
      expect(range.endRow, 3);
      expect(range.endColumn, 2);
      expect(range.isSingleCell, isTrue);
    });

    test('normalizes reversed coordinates', () => {
      const range = CellRange(5, 4, 2, 1);  // End before start

      expect(range.startRow, 2);
      expect(range.startColumn, 1);
      expect(range.endRow, 5);
      expect(range.endColumn, 4);
    });

    test('contains checks if cell is in range', () => {
      const range = CellRange(2, 1, 5, 4);

      expect(range.contains(const CellCoordinate(3, 2)), isTrue);
      expect(range.contains(const CellCoordinate(2, 1)), isTrue);  // Start corner
      expect(range.contains(const CellCoordinate(5, 4)), isTrue);  // End corner
      expect(range.contains(const CellCoordinate(1, 2)), isFalse); // Above
      expect(range.contains(const CellCoordinate(3, 5)), isFalse); // Right
    });

    test('rowCount and columnCount', () => {
      const range = CellRange(2, 1, 5, 4);

      expect(range.rowCount, 4);     // Rows 2, 3, 4, 5
      expect(range.columnCount, 4);  // Columns 1, 2, 3, 4
    });

    test('cellCount calculates total cells', () => {
      const range = CellRange(0, 0, 9, 4);  // 10 rows × 5 columns

      expect(range.cellCount, 50);
    });
  });
}
```

---

## Widget Testing

### Basic Widget Test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';

void main() {
  group('Worksheet Widget', () => {
    testWidgets('renders without error', (tester) async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
      final controller = WorksheetController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: data,
                controller: controller,
                rowCount: 100,
                columnCount: 26,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Worksheet), findsOneWidget);

      // Cleanup
      controller.dispose();
      data.dispose();
    });

    testWidgets('displays cell content', (tester) async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
      data.setCell(const CellCoordinate(0, 0), CellValue.text('Test Value'));

      final controller = WorksheetController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: data,
                controller: controller,
                rowCount: 100,
                columnCount: 26,
              ),
            ),
          ),
        ),
      );

      // Let the widget render
      await tester.pumpAndSettle();

      // The text is rendered in CustomPaint, so we verify the data is set
      expect(data.getCell(const CellCoordinate(0, 0))?.displayValue, 'Test Value');

      controller.dispose();
      data.dispose();
    });

    testWidgets('read-only mode prevents selection', (tester) async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
      final controller = WorksheetController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorksheetTheme(
              data: const WorksheetThemeData(),
              child: Worksheet(
                data: data,
                controller: controller,
                rowCount: 100,
                columnCount: 26,
                readOnly: true,
              ),
            ),
          ),
        ),
      );

      // Tap on the worksheet
      await tester.tap(find.byType(Worksheet));
      await tester.pump();

      // Selection should remain null in read-only mode
      expect(controller.hasSelection, isFalse);

      controller.dispose();
      data.dispose();
    });
  });
}
```

### Testing with pumpWidget

```dart
testWidgets('applies theme correctly', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  const customTheme = WorksheetThemeData(
    cellBackgroundColor: Color(0xFF123456),
    showHeaders: false,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: customTheme,
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify theme is accessible
  final context = tester.element(find.byType(Worksheet));
  final theme = WorksheetTheme.of(context);

  expect(theme.cellBackgroundColor, const Color(0xFF123456));
  expect(theme.showHeaders, isFalse);

  controller.dispose();
  data.dispose();
});
```

---

## Mocking WorksheetData

### Simple Mock Implementation

```dart
class MockWorksheetData implements WorksheetData {
  final Map<CellCoordinate, CellValue> _cells = {};
  final Map<CellCoordinate, CellStyle> _styles = {};

  @override
  final int rowCount;

  @override
  final int columnCount;

  MockWorksheetData({
    this.rowCount = 100,
    this.columnCount = 26,
  });

  @override
  CellValue? getCell(CellCoordinate coord) => _cells[coord];

  @override
  CellStyle? getStyle(CellCoordinate coord) => _styles[coord];

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    if (value == null) {
      _cells.remove(coord);
    } else {
      _cells[coord] = value;
    }
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    if (style == null) {
      _styles.remove(coord);
    } else {
      _styles[coord] = style;
    }
  }

  @override
  Stream<DataChangeEvent> get changes => const Stream.empty();

  @override
  void dispose() {
    _cells.clear();
    _styles.clear();
  }
}

// Usage in tests
testWidgets('handles mock data', (tester) async {
  final mockData = MockWorksheetData();
  mockData.setCell(const CellCoordinate(0, 0), CellValue.text('Mock'));

  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: mockData,
          controller: controller,
          rowCount: 100,
          columnCount: 26,
        ),
      ),
    ),
  );

  expect(mockData.getCell(const CellCoordinate(0, 0))?.displayValue, 'Mock');

  controller.dispose();
  mockData.dispose();
});
```

### Mock with Verification

```dart
class VerifyingMockWorksheetData extends MockWorksheetData {
  final List<CellCoordinate> getCellCalls = [];
  final List<(CellCoordinate, CellValue?)> setCellCalls = [];

  @override
  CellValue? getCell(CellCoordinate coord) {
    getCellCalls.add(coord);
    return super.getCell(coord);
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    setCellCalls.add((coord, value));
    super.setCell(coord, value);
  }

  void verifyGetCellCalled(CellCoordinate coord) {
    expect(getCellCalls, contains(coord));
  }

  void verifySetCellCalled(CellCoordinate coord, CellValue? value) {
    expect(setCellCalls, contains((coord, value)));
  }

  void reset() {
    getCellCalls.clear();
    setCellCalls.clear();
  }
}
```

---

## Simulating Pointer Gestures

### Tap Gesture

```dart
testWidgets('tap selects cell', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(
            rowHeaderWidth: 50.0,
            columnHeaderHeight: 24.0,
            defaultRowHeight: 24.0,
            defaultColumnWidth: 100.0,
          ),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Calculate position of cell A1 (0, 0)
  // Headers: 50px width, 24px height
  // Cell A1 starts at (50, 24)
  final cellA1Center = const Offset(50 + 50, 24 + 12);  // Center of A1

  await tester.tapAt(cellA1Center);
  await tester.pump();

  expect(controller.focusCell, const CellCoordinate(0, 0));

  controller.dispose();
  data.dispose();
});
```

### Drag Gesture

```dart
testWidgets('drag extends selection', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(
            rowHeaderWidth: 50.0,
            columnHeaderHeight: 24.0,
            defaultRowHeight: 24.0,
            defaultColumnWidth: 100.0,
          ),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Start at A1, drag to C3
  final startPoint = const Offset(100, 36);  // A1 center
  final endPoint = const Offset(300, 84);    // C3 center

  await tester.dragFrom(startPoint, endPoint - startPoint);
  await tester.pumpAndSettle();

  final range = controller.selectedRange!;
  expect(range.startRow, 0);
  expect(range.startColumn, 0);
  expect(range.endRow, 2);
  expect(range.endColumn, 2);

  controller.dispose();
  data.dispose();
});
```

### Double Tap Gesture

```dart
testWidgets('double tap triggers edit callback', (tester) async {
  final data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  final controller = WorksheetController();

  CellCoordinate? editedCell;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 100,
            columnCount: 26,
            onEditCell: (cell) {
              editedCell = cell;
            },
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // First tap to select
  await tester.tap(find.byType(Worksheet));
  await tester.pump(const Duration(milliseconds: 50));

  // Second tap to trigger edit
  await tester.tap(find.byType(Worksheet));
  await tester.pumpAndSettle();

  expect(editedCell, isNotNull);

  controller.dispose();
  data.dispose();
});
```

### Scroll Gesture

```dart
testWidgets('scroll updates scroll position', (tester) async {
  final data = SparseWorksheetData(rowCount: 10000, columnCount: 100);

  // Populate visible area
  for (var row = 0; row < 100; row++) {
    for (var col = 0; col < 10; col++) {
      data[(row, col)] = Cell.number((row * 10 + col).toDouble());
    }
  }

  final controller = WorksheetController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorksheetTheme(
          data: const WorksheetThemeData(),
          child: Worksheet(
            data: data,
            controller: controller,
            rowCount: 10000,
            columnCount: 100,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final initialScrollY = controller.scrollY;

  // Scroll down
  await tester.drag(find.byType(Worksheet), const Offset(0, -200));
  await tester.pumpAndSettle();

  expect(controller.scrollY, greaterThan(initialScrollY));

  controller.dispose();
  data.dispose();
});
```

---

## Performance Benchmarks

### Memory Benchmarks

Memory usage benchmarks ensure the widget remains efficient for large datasets. Refer to `test/benchmarks/memory_benchmark.dart` for detailed implementation.

### Startup (TTFR) Benchmarks

Time To First Render (TTFR) benchmarks measure how quickly the worksheet renders its initial frame. Refer to `test/benchmarks/startup_benchmark.dart` for detailed implementation.

### Interaction Benchmarks

Interaction benchmarks assess the responsiveness of user actions like typing, resizing, and complex selections. Refer to `test/benchmarks/interaction_benchmark.dart` for detailed implementation.

---

## Interpreting Benchmark Results & CI/CD Integration

Performance benchmarks are critical for maintaining the responsiveness and scalability of the Worksheet widget.

### Interpreting Results

*   **Latency Metrics (ms, µs):** Lower is better. Compare against predefined thresholds in `GEMINI.md` to identify regressions.
*   **Memory Usage (MB, Bytes/Cell):** Lower is better. Monitor for unexpected spikes, especially with increased data sizes. High memory usage can lead to Out-Of-Memory (OOM) errors on devices.
    *   **Note on Memory Benchmarking in Flutter Tests:** Direct programmatic access to detailed Dart VM heap statistics (e.g., via `vm_service` package) within `flutter test` can sometimes encounter resolution issues in certain environments. When this occurs, memory assertions within `test/benchmarks/memory_benchmark.dart` may be temporarily disabled. For robust, comprehensive memory profiling, it is recommended to use external tools like Perfetto or Flutter DevTools, often integrated into a CI/CD pipeline, to collect and analyze memory traces during benchmark runs.
*   **Frame Rate (FPS):** Higher is better (aim for 60 FPS). Drops in FPS during scrolling or animations indicate performance bottlenecks.

### CI/CD Integration

It is highly recommended to integrate these performance benchmarks into your Continuous Integration/Continuous Deployment (CI/CD) pipeline.

1.  **Automated Execution:** Configure your CI system (e.g., GitHub Actions, GitLab CI) to run `flutter test test/benchmarks/` on every pull request or significant commit.
2.  **Threshold Assertions:** The benchmarks contain `expect` assertions against predefined performance targets (SLAs). If a benchmark falls below its target, the CI build should fail, preventing performance regressions from being merged.
3.  **Historical Tracking:** Consider using specialized performance tracking tools (e.g., [Flutter's `perfetto_trace_processor`](https://github.com/flutter/flutter/wiki/Performance-Tracing-with-Perfetto)) or custom scripts to collect and store benchmark results over time. This allows for:
    *   Visualizing performance trends.
    *   Detecting gradual performance degradation that might not trigger a single test failure.
    *   Identifying the specific changes that introduced a regression.

---

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/core/span_list_test.dart

# Run tests matching pattern
flutter test --name "SpanList"

# Run all performance benchmarks
flutter test test/benchmarks/

# Generate coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```
