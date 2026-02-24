# Technical Debt & Optimization Guide

This document tracks known technical debt, architectural bottlenecks, and suggested optimizations for the Worksheet Widget project.

## 1. Core Layout & Geometry

### SpanList Performance (Scalability) — RESOLVED
- **Resolution:** Replaced cumulative array with a **Fenwick Tree (Binary Indexed Tree)**. `setSize()` is now O(log N) instead of O(N).
- **Benchmark results:** setSize at 1M spans: ~0.001ms (was ~26ms — **26,000x improvement**). Read paths (`positionAt`, `indexAtPosition`) remain O(log N) with negligible overhead (~170ns per call at 1M spans).
- **SLAs tightened:** 10K < 0.1ms, 100K < 0.1ms, 1M < 1ms. New read-path benchmarks: positionAt 10K@1M < 5ms, indexAtPosition 10K@1M < 10ms.

### LayoutSolver Caching — RESOLVED
- **Resolution:** Added last-result memoization for `getVisibleRows`/`getVisibleColumns`. Repeated calls with identical arguments return cached results at near-zero cost. Cache invalidated automatically by `setRowHeight`/`setColumnWidth`.
- **Benchmark results:** 1000 repeated identical lookups: 0.064ms total (was < 1ms uncached).
- **SLA tightened:** Repeated lookups < 1ms (was < 5ms).

## 2. Data Management

### Change Notification Thrashing — RESOLVED
- **Resolution:** Two-pronged fix:
  1. **Batched commit paths:** `_onInternalCommit` and `_onInternalCommitAndNavigate` now wrap `setCell`/`setFormat`/`setRichText` in `batchUpdate()`, emitting 1 range event instead of 3 individual events.
  2. **Microtask coalescing:** `_onDataChanged` buffers events into `_pendingDataChanges` and processes them in a single `scheduleMicrotask` pass — one `_layoutVersion++` and `setState()` per microtask frame, regardless of how many events arrive. Structural events (reset, row/column insert/delete) short-circuit to `invalidateAll`.

## 3. Rendering Pipeline

### TilePainter Optimization — PARTIALLY RESOLVED
- **Resolved:** Pre-allocated `_gridlinePaint` field in `TilePainter` — `_renderGridlines()` no longer allocates a new `Paint()` on every call. Only `strokeWidth` is mutated per call (varies by zoom bucket).
- **Not pursued (by design):**
  - **TextPainter Pooling:** Tiles are cached as `ui.Picture`, so `TextPainter` allocations only run on cache miss. The 1-TP-per-cell pattern is already near-optimal.
  - **Spillover Caching:** Same reasoning — only runs on cache miss. Spillover results are inherently tied to the cell's content and neighbors, making cache invalidation complex for minimal gain.
  - **Path Caching / Layer Hoisting:** Gridline `Path` construction is cheap relative to text layout. Since the entire tile is cached as a `ui.Picture`, separating gridlines into a distinct layer adds complexity without measurable benefit.

### TileManager Prefetching — RESOLVED
- **Resolution:** `getTilesForViewport()` now inflates the viewport by `prefetchRings * tileWidth` before computing tile coordinates. With the default `prefetchRings: 1`, this renders 1 ring of tiles beyond the visible area, eliminating white flashes during fast scrolling.
- **Implementation:** Uses `Rect.inflate()` — `TileCoordinate.fromPixelPosition` already clamps negatives to 0. The 100-tile LRU cache comfortably holds ~56 tiles (32 visible + 24 prefetch for 1080p).

### Auto-Fit Column Performance — RESOLVED
- **Previous State:** `_autoFitColumn()` created a `TextPainter` for every populated cell in the column — O(N) allocations and layout calls. On a 50K-row column, this caused a multi-hundred-millisecond UI freeze on double-click.
- **Resolution:** Display-value deduplication + character-length filtering. Plain text candidates are filtered to only the maximum character length (shorter strings are virtually always narrower). Rich text is deduped by display value. Capped at 1000 measurements for high-cardinality columns.
- **Benchmark results:** 50K cells with 16 unique values: ~12ms. 50K cells with unique sequential IDs: ~37ms. 50K cells with rich text: ~9ms. All well under the 200ms SLA.

### Jump-to-Edge Performance — RESOLVED
- **Previous State:** Two compounding issues caused a multi-second UI freeze when double-clicking near a column border after selecting a column:
  1. `_jumpToDataEdge` scanned cell-by-cell through up to ~1M empty rows when focus was at the sheet boundary (e.g., after column selection set focus to row 1,048,575).
  2. `TileManager.getCellRangeForTile` had a boundary clamping bug: when prefetched tiles extended beyond the content area (e.g., tile pixel top >= totalHeight), `getRowAt()` returned -1, which was clamped to `startRow=0` while `endRow` was clamped to `maxRow=1048575`. This caused the tile painter to iterate over the **entire sheet** (1M+ rows × columns) for each boundary tile, taking 6+ seconds per tile.
- **Resolution:**
  1. Added `findNextPopulatedRow`/`findPrevPopulatedRow`/`findNextPopulatedColumn`/`findPrevPopulatedColumn` methods to `WorksheetData` (with default cell-by-cell implementations for backward compatibility). `SparseWorksheetData` overrides these with efficient key scans. `_jumpToDataEdge`'s "empty adjacent" branch now calls these sparse lookups instead of looping.
  2. Fixed `getCellRangeForTile` to distinguish "before content" (clamp to 0) from "after content" (clamp to maxRow/maxCol) when `getRowAt`/`getColumnAt` returns -1. Boundary tiles now get a single-row/column range instead of the entire sheet.
- **Benchmark results:** Jump UP across 1M empty rows: ~2.8ms. Jump RIGHT across 16K empty columns: ~0.02ms. Full desktop double-tap gesture + scroll + render: ~35ms. All well under the 200ms SLA.

## 4. Interaction & UX

### WorksheetGestureHandler Decomposition — RESOLVED
- **Resolution:** Extracted `FillDragHandler` and `MoveDragHandler` as sub-objects that encapsulate fill-specific and move-specific state and logic. The coordinator keeps tap, double-tap, selection drag, resize drag, and handle drag (simpler, tightly coupled). Reduced `gesture_handler.dart` from 783 lines to ~530 lines.
- **New files:** `lib/src/interaction/gestures/fill_drag_handler.dart`, `lib/src/interaction/gestures/move_drag_handler.dart`
- **Tests:** Direct unit tests for sub-handlers + all 88 existing integration tests continue to pass through delegation.

### Keyboard Shortcuts — RESOLVED
- **Resolution:** Already fully migrated to Flutter's `Actions`/`Intents` system (`shortcuts/` directory with 40+ bindings, 21 Intents, 25 Actions). Deprecated `keyboard_handler.dart` deleted. Remaining raw key handlers (`_handleKeyBeforeShortcuts`, cell editor overlay) are intentionally raw — they handle type-to-edit triggers, escape during drag, formula mode arrow keys, and autocomplete navigation that don't fit the declarative Shortcuts model.

## 5. Missing Core Features

### Formula Evaluation Integration (worksheet_formula)
- **Current State:** `CellValue.formula` exists, but there is no integration with the external `worksheet_formula` engine.
- **Suggestion:**
  - **EvaluationContext Implementation:** Create a bridge that implements `worksheet_formula`'s `EvaluationContext`, mapping `A1` coordinates and `A1Range` to this package's `CellCoordinate` and `CellRange`.
  - **Value Translation:** Implement bi-directional mapping between `CellValue` (this package) and `FormulaValue` (engine), ensuring Excel-compatible errors like `#DIV/0!` are handled correctly.
  - **AST Caching:** Store parsed `AST` nodes alongside `CellValue.formula` to avoid re-parsing during every evaluation cycle.
  - **Dependency Tracking:** Integrate the engine's `DependencyGraph` to track cell relationships. When `WorksheetData` changes, use the graph to identify and re-evaluate only the affected dependent cells, triggering targeted `TileManager.invalidateRange` calls.
  - **Asynchronous Evaluation:** For complex sheets, evaluate formulas in a background isolate or using microtasks to prevent blocking the UI thread during large-scale recalculations.

### Frozen Panes Integration — RESOLVED
- **Resolution:** Wired existing `FreezeConfig` model and `FrozenLayer` renderer into the `Worksheet` widget with full integration across all subsystems:
  1. **Widget integration:** Added `freezeConfig` property to `Worksheet`, `FrozenLayer` lifecycle management (init, didUpdateWidget, dispose, reassemble), `_FrozenLayerPainter` and `_FrozenSelectionPainter` in the build Stack (between selection and headers).
  2. **Hit testing:** `WorksheetHitTester.screenToWorksheet()` suppresses scroll offset on frozen axes so taps in frozen regions resolve to the correct unscrolled cell.
  3. **Scroll-to-cell:** `WorksheetController.scrollToCell()` skips scrolling for frozen cells and reduces visible area by frozen dimensions when scrolling to non-frozen cells.
  4. **Elastic overscroll suppression:** `SuppressibleBouncingPhysics.applyBoundaryConditions()` prevents overscroll at min extent on axes with frozen panes, keeping frozen content flush with non-frozen content (no elastic gap at the frozen boundary). Bottom/right bounce is unaffected.
  5. **Frozen headers:** `HeaderLayer` overpaints frozen column/row headers at fixed positions (zero scroll offset on the frozen axis) with separator lines at the freeze boundary matching the `FrozenLayer` separator style.
- **New files:** `example/frozen_panes.dart`, `test/widgets/frozen_panes_integration_test.dart`

### ~~Undo/Redo System~~ (RESOLVED)
- **Resolution:** Implemented range-scoped snapshot-based undo/redo via `UndoManager`, `UndoSnapshot`, and `UndoEntry`. All 13 mutation paths are wrapped with `recordUndo`. Keyboard shortcuts: Ctrl+Z / Cmd+Z (undo), Ctrl+Y / Ctrl+Shift+Z / Cmd+Shift+Z (redo).

## 6. Testing & Quality

### Golden Test Coverage
- **Current State:** Limited golden tests for complex rendering states (merges + spillover + borders).
- **Suggestion:** Add more golden tests covering edge cases of the rendering pipeline.

## Summary of Priority Actions

### Resolved (Performance)
1. ~~**TilePainter Optimization**~~ — PARTIALLY RESOLVED (gridline Paint pre-allocated; pooling/caching not pursued — tiles cached as `ui.Picture` makes per-cell optimizations moot).
2. ~~**TileManager Prefetching**~~ — RESOLVED (1-ring prefetch eliminates white flashes).
3. ~~**SpanList Performance**~~ — RESOLVED (Fenwick tree: setSize O(log N), 26,000x improvement).
4. ~~**LayoutSolver Caching**~~ — RESOLVED (memoization for repeated lookups).
5. ~~**Auto-Fit Column Performance**~~ — RESOLVED (deduplication + length filtering).
6. ~~**Jump-to-Edge Performance**~~ — RESOLVED (sparse lookups + boundary tile clamping fix).

### Resolved (Architecture)
7. ~~**WorksheetGestureHandler Decomposition**~~ — RESOLVED (extracted `FillDragHandler` + `MoveDragHandler` sub-objects).
8. ~~**Keyboard Shortcuts**~~ — RESOLVED (fully migrated to `Actions`/`Intents`; deprecated handler deleted).

### Resolved (Data)
9. ~~**Change Notification Thrashing**~~ — RESOLVED (batched commit paths + microtask coalescing).

### Open
10. **Low Priority (Features):** Formula Engine Integration, ~~Frozen Panes~~, ~~Undo/Redo~~.
11. **Low Priority (Testing):** Golden test coverage for complex rendering states.
