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

### Change Notification Thrashing
- **Current State:** Batch updates emit a single `range` event, but individual `setCell` calls emit many individual events.
- **Impact:** Redundant tile invalidations.
- **Suggestion:** Ensure all multi-cell operations (like Paste or Fill) strictly use `batchUpdate`. Consider debouncing change events at the `WorksheetData` level.

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

### God Object: WorksheetGestureHandler
- **Current State:** `WorksheetGestureHandler` handles too many responsibilities (tap, double-tap, drag, resize, selection, scrolling coordination).
- **Impact:** Difficult to maintain and test; hard to add specialized mobile gestures.
- **Suggestion:** Decompose into specialized handlers:
  - `SelectionGestureHandler`
  - `ResizeGestureHandler`
  - `EditGestureHandler`
  - `MobileGestureHandler` (for long-press, etc.)

### Keyboard Interaction
- **Current State:** Shortcut logic is currently split between `shortcuts/` and `interaction/`.
- **Impact:** Inconsistent behavior between keyboard and mouse interactions.
- **Suggestion:** Fully migrate all interaction logic to the `Actions`/`Intents` system.

## 5. Missing Core Features

### Formula Evaluation Integration (worksheet_formula)
- **Current State:** `CellValue.formula` exists, but there is no integration with the external `worksheet_formula` engine.
- **Suggestion:**
  - **EvaluationContext Implementation:** Create a bridge that implements `worksheet_formula`'s `EvaluationContext`, mapping `A1` coordinates and `A1Range` to this package's `CellCoordinate` and `CellRange`.
  - **Value Translation:** Implement bi-directional mapping between `CellValue` (this package) and `FormulaValue` (engine), ensuring Excel-compatible errors like `#DIV/0!` are handled correctly.
  - **AST Caching:** Store parsed `AST` nodes alongside `CellValue.formula` to avoid re-parsing during every evaluation cycle.
  - **Dependency Tracking:** Integrate the engine's `DependencyGraph` to track cell relationships. When `WorksheetData` changes, use the graph to identify and re-evaluate only the affected dependent cells, triggering targeted `TileManager.invalidateRange` calls.
  - **Asynchronous Evaluation:** For complex sheets, evaluate formulas in a background isolate or using microtasks to prevent blocking the UI thread during large-scale recalculations.

### Frozen Panes Integration
- **Current State:** `FrozenLayer` infrastructure exists but isn't fully wired into the main viewport scrolling logic.
- **Suggestion:** Complete the implementation of `WorksheetViewport` to support fixed "sticky" regions that don't move with the main scroll.

### Undo/Redo System
- **Current State:** No built-in support for undoing edits or formatting changes.
- **Suggestion:** Implement a **Command Pattern** for all `WorksheetData` modifications and maintain a `CommandHistory`.

## 6. Testing & Quality

### Golden Test Coverage
- **Current State:** Limited golden tests for complex rendering states (merges + spillover + borders).
- **Suggestion:** Add more golden tests covering edge cases of the rendering pipeline.

## Summary of Priority Actions

1. ~~**High Priority (Performance):** Implement `TextPainter` pooling and `Path` caching in `TilePainter`.~~ — PARTIALLY RESOLVED (gridline Paint pre-allocated; other items not pursued — see assessment above).
2. ~~**High Priority (User Experience):** Implement Tile Prefetching in `TileManager`.~~ — RESOLVED.
3. **Medium Priority (Architecture):** Decompose `WorksheetGestureHandler`.
4. **Low Priority (Features):** Complete Formula Engine Integration and Frozen Panes.
