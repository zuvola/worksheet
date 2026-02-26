# Worksheet Widget

[![pub package](https://img.shields.io/pub/v/worksheet.svg)](https://pub.dev/packages/worksheet)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/sjhorn/worksheet/actions/workflows/tests.yml/badge.svg)](https://github.com/sjhorn/worksheet/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/sjhorn/worksheet/branch/main/graph/badge.svg)](https://codecov.io/gh/sjhorn/worksheet)

A high-performance Flutter widget that brings Excel-like spreadsheet functionality to your app. Supporting 10%-400% zoom with GPU-optimized tile-based rendering.

![Worksheet Screenshot](doc/images/worksheet_screenshot.png)

Display and edit tabular data with smooth scrolling, pinch-to-zoom, and cell selection - all running at 60fps even with hundreds of thousands of rows.

---

## 🛠 For Developers

- **[Developer Guide](doc/DEVELOPMENT.md)** — Prerequisites, project structure, and TDD workflow
- **[Architecture Overview](doc/ARCHITECTURE.md)** — Deep dive into the rendering pipeline and coordinate systems
- **[Performance Guide](doc/PERFORMANCE.md)** — Tile cache tuning and large dataset strategies
- **[Full API Reference](doc/API.md)** — Quick reference for all classes and methods

### Quick Start for Contributors

```bash
git clone https://github.com/sjhorn/worksheet.git
cd worksheet
flutter pub get
flutter run -t example/main.dart  # Run the full demo
flutter test                     # Verify with all tests
```

---

## 🚀 Performance at a Glance

The worksheet is built on three foundational technologies to achieve 60fps scrolling:

1.  **`TwoDimensionalScrollable`**: Built-in Flutter 2D scroll management
2.  **`LeafRenderObjectWidget`**: Direct render object control for custom high-speed painting
3.  **`ui.Picture` / `PictureRecorder`**: GPU-backed tile caching for efficient rendering

### Benchmark SLAs (Automated in CI)

We maintain strict performance targets verified on every commit:

| Operation | Target | Description |
|-----------|--------|-------------|
| **Tile render** | < 8ms | Max time to draw a 256px visible tile |
| **Hit test** | < 100µs | Latency to resolve screen tap to cell |
| **Visible range** | < 2ms | Viewport calculation at any scroll/zoom |
| **Selection** | < 1ms | Range selection even at Excel-scale |
| **Resize** | < 0.1ms | O(log n) row/column updates via BIT |

---

## Try It In 30 Seconds

```dart
import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(MaterialApp(home: MySpreadsheet()));

class MySpreadsheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Populate data efficiently with SparseWorksheetData
    final data = SparseWorksheetData(rowCount: 100, columnCount: 10, cells: {
        (0, 0): 'Name'.cell,
        (0, 1): 'Amount'.cell,
        (1, 0): 'Apples'.cell,
        (1, 1): 42.cell,
        (2, 1): '=2+42'.formula,
    });

    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: data,
          rowCount: 100,
          columnCount: 10,
        ),
      ),
    );
  }
}
```

---

## Selection, Editing, and More

### Add Selection and Editing

Want users to select and edit cells? Add a controller and callbacks:

```dart
class EditableSpreadsheet extends StatefulWidget {
  @override
  State<EditableSpreadsheet> createState() => _EditableSpreadsheetState();
}

class _EditableSpreadsheetState extends State<EditableSpreadsheet> {
  final _data = SparseWorksheetData(rowCount: 1000, columnCount: 26);
  final _controller = WorksheetController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
        child: Worksheet(
          data: _data,
          controller: _controller,
          rowCount: 1000,
          columnCount: 26,
          onCellTap: (cell) {
            print('Tapped ${cell.toNotation()}');  // "A1", "B5", etc.
          },
          onEditCell: (cell) {
            // Double-tap triggers edit - implement your editor UI
            print('Edit ${cell.toNotation()}');
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _data.dispose();
    super.dispose();
  }
}
```

### Format Your Numbers

Display values as currency, percentages, dates, and more using Excel-style format codes:

```dart
final data = SparseWorksheetData(rowCount: 100, columnCount: 10, cells: {
    (0, 0): 'Revenue'.cell,
    (0, 1): Cell.number(1234.56, format: CellFormat.currency),     // "$1,234.56"
    (1, 0): 'Growth'.cell,
    (1, 1): Cell.number(0.085, format: CellFormat.percentage),     // "9%"
    (2, 0): 'Date'.cell,
    (2, 1): Cell.date(DateTime(2024, 1, 15), format: CellFormat.dateIso), // "2024-01-15"
});
```

### Automatic Type & Format Detection

Type values into cells and they're stored as the right type automatically:

```dart
// Detected automatically during editing and paste:
// "$1,234.56"       → CellValue.number(1234.56)                format: currency
// "2025-01-15"      → CellValue.date(DateTime(2025, 1, 15))    format: dateIso
// "42%"             → CellValue.number(0.42)                   format: percentage
// "=SUM(A1:A5)"     → CellValue.formula('=SUM(A1:A5)')
```

### Rich Text and Cell Merging

Style individual words within a cell and merge cells into regions:

```dart
final data = SparseWorksheetData(rowCount: 100, columnCount: 10, cells: {
    // Rich text: inline bold + colored text in one cell
    (0, 0): Cell.text('Total Revenue', richText: const [
      TextSpan(text: 'Total ', style: TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: 'Revenue', style: TextStyle(color: Color(0xFF4472C4))),
    ]),
});

// Merge cells A1:D1 into a single wide cell
data.mergeCells(CellRange(0, 0, 0, 3));
```

---

## Why This Widget?

- **Sparse storage**: Memory scales with data, not grid size (100K cells = ~20MB)
- **10%-400% zoom**: Smooth pinch-to-zoom with automatic level-of-detail
- **Full selection**: Single cell, ranges, entire rows/columns, and multi-select
- **Keyboard navigation**: ~44 default bindings (Arrows, Tab, Enter, Ctrl+C/V, Ctrl+Z/Y, etc.)
- **Formula features**: Click cells to insert references, autocomplete function names
- **Mobile support**: Touch gestures, selection handles, pinch-to-zoom
- **Theming**: Full control over colors, fonts, headers — built-in light/dark presets

---

## Documentation Index

### 📖 User Guides
- [Getting Started](doc/GETTING_STARTED.md) — Installation, basic setup, enabling editing
- [Cookbook](doc/COOKBOOK.md) — Practical recipes for common tasks
- [Theming Guide](doc/THEMING.md) — Colors, fonts, headers, and selection styles
- [Mobile Interaction](doc/MOBILE_INTERACTION.md) — Touch gestures and handles
- [Mouse Cursors](doc/MOUSE_CURSOR.md) — Desktop cursor behavior and hit zones

### 🧩 Feature References
- [Cell Merging](doc/CELL_MERGING.md) — Merge types, data rules, and rendering
- [Cell Spillover](doc/CELL_SPILLOVER.md) — Text overflow into adjacent empty cells
- [Cell Referencing](doc/CELL_REFERENCING.md) — Formula editing and A1 notation
- [Formula Autocomplete](doc/AUTOCOMPLETE.md) — Autocomplete dropdown specification

### 🏗 Internal Architecture & Performance
- [Architecture](doc/ARCHITECTURE.md) — Deep dive into the rendering pipeline
- [Performance](doc/PERFORMANCE.md) — Tile cache tuning and benchmarks
- [Testing Guide](doc/TESTING.md) — Unit tests, widget tests, and benchmarks
- [Development Guide](doc/DEVELOPMENT.md) — Contribution workflow and project structure
- [Contributing](CONTRIBUTING.md) — How to propose changes and run checks
- [Code of Conduct](CODE_OF_CONDUCT.md) — Community expectations
- [Security](SECURITY.md) — Responsible disclosure
- [Support](SUPPORT.md) — Where to ask questions

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  worksheet: ^3.6.0
```

---

## Keyboard Shortcuts

All shortcuts work out of the box. You can override or extend them via the `shortcuts` and `actions` parameters.

| Key | Action |
|-----|--------|
| Arrow keys | Move selection |
| Shift + Arrow | Extend selection |
| Tab / Shift+Tab | Move right/left |
| Enter / Shift+Enter | Move down/up |
| Home / End | Start/end of row |
| Ctrl+Home / Ctrl+End | Go to A1 / last cell |
| F2 | Edit current cell |
| Escape | Cancel active drag; or collapse range to single cell |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / Cut / Paste |
| Ctrl+Z / Ctrl+Y | Undo / Redo |
| Alt+Enter | Insert newline (when cell has wrapText) |
| Ctrl+B / Ctrl+I / Ctrl+U | Toggle bold / italic / underline (editing) |
| F4 | Cycle absolute/relative reference (formula editing) |

---

## Examples & Demos

Run these from the `example/` directory:

| File | Feature Demonstrated |
|------|----------------------|
| `main.dart` | **Full Demo**: 50K rows, editing, resizing, zoom |
| `simple.dart` | Minimal smallest working worksheet |
| `merge.dart` | Cell merging with toolbar controls |
| `border.dart` | Complex border styles and junctions |
| `rich_text/` | Inline styling with Google Fonts |
| `undo_redo.dart` | Full undo/redo history tracking |
| `autocomplete.dart` | Formula function autocomplete |

```bash
cd example
flutter run -t merge.dart
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.
