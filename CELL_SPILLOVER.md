# Overflow Behavior

## Horizontal Overflow

**Text overflows into adjacent empty cells (right)**
- Default behavior for left-aligned text in a cell when neighboring cells to the right are empty
- Text visually spills across cell boundaries but remains owned by the original cell
- Overflow stops at the first non-empty adjacent cell — text appears truncated at that boundary

**Right-to-left overflow**
- Right-aligned text can overflow leftward into empty cells to the left
- Center-aligned text overflows in both directions symmetrically

**No overflow (truncation)**
- When adjacent cells contain data, the text is visually clipped at the cell border
- The full content is still there (visible in the formula bar), just not rendered

**Wrap Text mode**
- When "Wrap Text" is enabled, horizontal overflow is suppressed entirely
- Text wraps within the cell width, and the row height grows to accommodate (unless manually fixed)

**Shrink to Fit**
- Font size is reduced until all content fits within the cell width
- No overflow occurs; no wrapping occurs

**Merged cells**
- The "cell width" for overflow purposes becomes the total width of the merged range
- Overflow beyond the merged area follows the same rules as above

## Vertical Overflow

**Row height auto-expand**
- When Wrap Text is on and row height is set to auto, the row grows vertically to fit all wrapped lines
- This is the primary "vertical overflow" mechanism

**Vertical clipping**
- If row height is manually fixed (not auto), wrapped text that exceeds the row height is clipped at the bottom
- Content is hidden, not gone

**No native vertical overflow into cells below**
- Unlike horizontal, Excel never visually spills content into the cell below. Vertical overflow is always either accommodated (row grows) or clipped.

## Summary Table

| Scenario | H-Align | Wrap Text | Adjacent cell empty? | Row height | Result |
|---|---|---|---|---|---|
| Default | Left | Off | Yes | Auto | Overflows right |
| Default | Left | Off | No | Auto | Truncated visually |
| Default | Right | Off | Yes | Auto | Overflows left |
| Default | Center | Off | Yes | Auto | Overflows both directions |
| Wrapped | Any | On | N/A | Auto | Wraps, row expands |
| Wrapped + fixed row | Any | On | N/A | Fixed | Wraps, clipped at bottom |
| Shrink to fit | Any | Off | N/A | Any | Font shrinks, no overflow |

## Implementation

### Status

| Feature | Status |
|---------|--------|
| Left-aligned text spills right | Done |
| Right-aligned text spills left | Done |
| Center-aligned text spills both | Done |
| Stops at non-empty cell | Done |
| Stops at merged cell region | Done |
| Stops at sheet edge | Done |
| Wrap-text suppresses spillover | Done |
| Number/date/duration/boolean → `######` | Done |
| Merged cell source spills from merge edge | Done |
| Tile expansion zone (cross-tile spillover) | Done |
| Frozen pane spillover | Done |
| Shrink-to-fit | Not implemented (separate feature) |
| Vertical spillover | N/A (matches Excel — never spills vertically) |

### Key Classes

- **`SpilloverCalculator`** (`lib/src/core/geometry/spillover_calculator.dart`) — Pure utility that computes `SpilloverExtent` (start/end column, total width, hash-fill flag). No rendering dependencies.
- **`TilePainter._renderCellContent()`** — Uses `SpilloverCalculator` for non-wrap cells: measures unconstrained text, computes spillover, paints with expanded clip rect or `######`.
- **`FrozenLayer._paintCellContent()`** — Same logic as `TilePainter` but converts between zoomed screen coordinates and worksheet coordinates.

### Cross-References

- [Cell Merging](CELL_MERGING.md) — Spillover stops at merged cell boundaries; merged sources spill from the merge edge.
- [Architecture](ARCHITECTURE.md) — Tile-based rendering pipeline that spillover integrates with.