# Technical Debt & Optimization Guide

This document tracks known technical debt, architectural bottlenecks, and suggested optimizations for the Worksheet Widget project.

## 1. Data Management

### Change Notification Thrashing
- **Current State:** Batch updates emit a single `range` event, but individual `setCell` calls emit many individual events.
- **Impact:** Redundant tile invalidations.
- **Suggestion:** Ensure all multi-cell operations (like Paste or Fill) strictly use `batchUpdate`. Consider debouncing change events at the `WorksheetData` level.

## 2. Rendering Pipeline

### TilePainter Optimization
- **Current State:**
  - `TextPainter` is allocated and laid out for every cell in every tile render (though disposed immediately).
  - `SpilloverCalculator.compute` is called inside the cell loop for every overflowing cell.
  - `_renderGridlines` builds a complex `Path` on every tile render.
- **Impact:** High GPU/CPU overhead during fast scrolling or zoom animations.
- **Suggestion:**
  - **TextPainter Pooling:** Maintain a pool of `TextPainter` objects to reduce allocation churn.
  - **Spillover Caching:** Cache spillover results per row/column.
  - **Path Caching:** Cache the gridline `Path` for a tile. Gridlines only change if row/column sizes change.
  - **Layer Hoisting:** Move static elements (gridlines) into a separate `ui.Image` or `Picture` that is only re-rendered when layout changes.

### TileManager Prefetching
- **Current State:** `TileConfig` has `prefetchRings`, but `TileManager.getTilesForViewport` currently only fetches the strictly visible tiles.
- **Impact:** Visible "white flashes" or checkerboarding during very fast scrolling.
- **Suggestion:** Implement the prefetching logic in `TileManager` to render tiles 1-2 rings outside the viewport in a background microtask.

## 3. Interaction & UX

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

## 4. Missing Core Features

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

## 5. Testing & Quality

### Golden Test Coverage
- **Current State:** Limited golden tests for complex rendering states (merges + spillover + borders).
- **Suggestion:** Add more golden tests covering edge cases of the rendering pipeline.

## Summary of Priority Actions

1. **High Priority (Performance):** Implement `TextPainter` pooling and `Path` caching in `TilePainter`.
2. **High Priority (User Experience):** Implement Tile Prefetching in `TileManager`.
3. **Medium Priority (Architecture):** Decompose `WorksheetGestureHandler`.
4. **Low Priority (Features):** Complete Formula Engine Integration and Frozen Panes.
