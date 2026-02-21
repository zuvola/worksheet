# Spreadsheet Cell Border Rendering Algorithm

## Research Summary

This problem has been **partially solved** in several contexts, but no single comprehensive open-source solution exists that handles all the nuances you describe:

1. **CSS `border-collapse: collapse`** — The W3C CSS spec defines a conflict resolution algorithm for HTML tables. Priority: `hidden` > widest border > style precedence (`double` > `solid` > `dashed` > `dotted` > ...) > element hierarchy (cell > row > table). However, this is for HTML rendering only and doesn't address pixel-level corner joining of thick/double borders.

2. **OOXML (ECMA-376)** — Microsoft's spec for Word/Excel defines border conflict resolution: assign weights by style, heavier border wins; if equal, darker color wins; if equal, reading-order wins. But this is a *data model* spec — it says *which* border wins at a shared edge, not *how* to render the junction pixels.

3. **SpreadJS (GrapeCity/Mescius)** — Commercial spreadsheet widget that handles this in their rendering engine, but closed-source.

4. **Excel itself** — Has known rendering bugs (e.g., borders at sheet edges are clipped by 2px). The rendering is done in their closed-source GDI/DirectX engine.

**The gap**: No public algorithm addresses the **pixel-level rendering** of how thick (2–3px) and double (line-gap-line) borders join at corners and T-junctions when adjacent cells have different border styles. This is what your algorithm needs to solve.

---

## Data Model

### Border Types

```
NONE    = 0   →  0px  (no border)
THIN    = 1   →  1px  (single line)
THICK   = 2   →  3px  (single fat line, centered on grid edge)
DOUBLE  = 3   →  3px  (1px line + 1px gap + 1px line, centered on grid edge)
```

All multi-pixel borders are **centered** on the logical grid edge. This means a 3px border extends 1px into each adjacent cell and occupies 1px on the grid line itself.

### Cell Border Storage

Each cell stores borders for its **top** and **left** edges only. The right edge of cell `(r, c)` is the left edge of cell `(r, c+1)`. The bottom edge of cell `(r, c)` is the top edge of cell `(r+1, c)`.

```
CellBorder {
    style: NONE | THIN | THICK | DOUBLE
    color: Color
}

Grid {
    // Horizontal edges: hBorders[row][col] = border on top edge of cell (row, col)
    // Rows 0..numRows (row numRows = bottom edge of last row)
    hBorders: CellBorder[numRows+1][numCols]
    
    // Vertical edges: vBorders[row][col] = border on left edge of cell (row, col)
    // Cols 0..numCols (col numCols = right edge of last col)
    vBorders: CellBorder[numRows][numCols+1]
}
```

This avoids duplication entirely — every physical edge is stored exactly once.

---

## Phase 1: Edge Conflict Resolution

When the user sets "cell (2,3) right border = THICK red", you're actually writing to `vBorders[2][4]`. If cell (2,4) also has a left border defined, you need conflict resolution.

### Resolution Rules (follows Excel/OOXML behavior)

For any shared edge where two cells contribute conflicting borders:

```
function resolveEdge(borderA, borderB) → CellBorder:
    // 1. "Last write wins" for user actions (Excel behavior)
    //    OR use priority-based resolution:
    
    // 2. Higher style weight wins
    weightA = styleWeight(borderA.style)
    weightB = styleWeight(borderB.style)
    if weightA != weightB:
        return weightA > weightB ? borderA : borderB
    
    // 3. Equal weight: darker color wins
    brightnessA = brightness(borderA.color)
    brightnessB = brightness(borderB.color)
    if brightnessA != brightnessB:
        return brightnessA < brightnessB ? borderA : borderB
    
    // 4. Equal: first in reading order (left/top wins)
    return borderA

function styleWeight(style):
    NONE   → 0
    THIN   → 1
    THICK  → 3    // by pixel width
    DOUBLE → 3    // same total width as thick
    // If THICK == DOUBLE in weight, use style precedence:
    // DOUBLE > THICK > THIN > NONE (matches CSS spec)
```

**Important**: In practice, Excel uses "last write wins" — if you set cell A1's right border to thin, then set B1's left border to thick, the thick border is displayed. This is simpler to implement and what users expect.

---

## Phase 2: Edge Rendering (Drawing Individual Edges)

Each edge occupies pixels relative to the **grid line position** (the logical boundary between cells).

```
Given a horizontal edge at pixel-Y position `gy`:
    THIN:    draw 1px line at y = gy
    THICK:   draw 3px line at y = gy-1 to gy+1  (centered)
    DOUBLE:  draw 1px at y = gy-1, skip gy, draw 1px at y = gy+1

Given a vertical edge at pixel-X position `gx`:
    THIN:    draw 1px line at x = gx
    THICK:   draw 3px line at x = gx-1 to gx+1  (centered)
    DOUBLE:  draw 1px at x = gx-1, skip gx, draw 1px at x = gx+1
```

### Pixel Footprint Map

```
Style    Offset from grid line    Total px
─────    ────────────────────    ────────
THIN     [0]                     1
THICK    [-1, 0, +1]             3
DOUBLE   [-1, _, +1]             3  (center pixel is gap)
```

### Double Border Sub-Line Algorithm

A double border consists of two sub-lines: **outer** and **inner**, separated by a 1px gap channel.

**Outer sub-line** (closer to the cell exterior / sheet edge):
- Extended at endpoints via `startExt`/`endExt` when no perpendicular double
  border exists at that endpoint.
- The `outerSign` parameter (-1 for top/left, +1 for bottom/right) determines
  which direction is "outer."

**Inner sub-line** (closer to the cell interior):
- Extended by 1px at endpoints where no perpendicular double border exists
  (needed to close gaps at outer sheet edges due to butt-cap rendering).

**Junction-aware shortening** (perpA / perpB):

Each endpoint of a double border has two perpendicular border "halves" —
one on each side of the junction point:
- **perpA**: the perpendicular border on the same cell (e.g., `borders.left`
  for the top border's left endpoint — goes DOWN from the junction).
- **perpB**: the perpendicular border from the neighbor cell on the opposite
  side (e.g., the cell above's left border — goes UP from the junction).

Shortening rules:
- **Inner sub-lines** shorten when `perpA OR perpB` is double. This preserves
  the gap channel at ALL junction types (L-corners, T-junctions, + junctions).
- **Outer sub-lines** shorten when `perpA AND perpB` are both double
  (+ junctions only). At L-corners and edge T-junctions, outers extend
  through, covering corner pixels via their endpoint extensions.
  Additionally, the horizontal outer's **left-side** (start) extension is
  reduced by 1px so it aligns with the cell boundary rather than extending
  past it — the vertical outer's extension already covers that corner pixel.
- **Corner dots** (filling the 4 diagonal pixels of the 3x3 junction block)
  are drawn when the outer is shortened, covering pixels that neither
  the outer nor inner sub-lines reach.

**Skia pixel coordinate model** (`isAntiAlias = false`):
- Pixel (px, py) has its center at the integer coordinate (px, py).
- A 1px stroke from (px, py) to (px+1, py) fills exactly pixel (px, py).
- Corner dot positions use `.floor()` to convert half-pixel sub-line
  coordinates to the correct target pixel.

```
+ junction (all 4 sides double, both outers shortened):

    ■ □ ■      Both outer and inner shortened, corner dots fill diagonals.
    □ □ □      Gap channels preserved in all 4 directions.
    ■ □ ■

L-corner (2 sides double, both outers extend through):

    ■ ■ ■      Horizontal outer extends through.
    ■ □ □      Vertical outer extends through gap row.
    ■ □ ■      Vertical outer + inner.

Edge T-junction (3 sides double, outers extend on open edge):

    ■ ■ ■      Horizontal outer extends (perpB null → && false).
    ■ □ □      Vertical outer extends through gap row.
    ■ □ ■      Vertical outer + inner.
```

---

## Phase 3: Corner/Junction Resolution (The Hard Part)

At every grid intersection point, up to 4 edges meet (top, bottom, left, right). The junction must be drawn so that all borders connect seamlessly without overlap artifacts.

### Junction Classification

At grid point `(row, col)`, the four contributing edges are:

```
          edgeUp    = vBorder at (row-1, col)   [vertical edge above]
          edgeDown  = vBorder at (row, col)     [vertical edge below]
          edgeLeft  = hBorder at (row, col-1)   [horizontal edge to left]
          edgeRight = hBorder at (row, col)     [horizontal edge to right]
```

Visualized:

```
              edgeUp
                │
                │
 edgeLeft ──────┼────── edgeRight
                │
                │
             edgeDown
```

### The Junction Pixel Grid

For thick/double borders, the junction area is a **3×3 pixel block** centered on the grid intersection point:

```
    (-1,-1) (-1, 0) (-1,+1)
    ( 0,-1) ( 0, 0) ( 0,+1)
    (+1,-1) (+1, 0) (+1,+1)
```

Each of the 9 pixels must be resolved based on which edges contribute to that position.

### Junction Algorithm

```
function renderJunction(gx, gy, edgeUp, edgeDown, edgeLeft, edgeRight):
    // For each pixel in the 3x3 junction block:
    for dy in [-1, 0, +1]:
        for dx in [-1, 0, +1]:
            pixel = resolveJunctionPixel(dx, dy, edgeUp, edgeDown, edgeLeft, edgeRight)
            if pixel != TRANSPARENT:
                drawPixel(gx + dx, gy + dy, pixel.color)


function resolveJunctionPixel(dx, dy, up, down, left, right) → {color} | TRANSPARENT:
    // Collect which edges "claim" this pixel
    contributors = []
    
    // Vertical edges (up/down) contribute to column dx
    // A vertical edge at offset dx means:
    //   THIN:   only dx=0
    //   THICK:  dx in {-1, 0, +1}
    //   DOUBLE: dx in {-1, +1} (dx=0 is gap)
    
    if dy <= 0 and edgeUp.style != NONE:
        if occupiesOffset(edgeUp.style, dx, 'vertical'):
            contributors.add({edge: edgeUp, axis: 'vertical'})
    
    if dy >= 0 and edgeDown.style != NONE:
        if occupiesOffset(edgeDown.style, dx, 'vertical'):
            contributors.add({edge: edgeDown, axis: 'vertical'})
    
    // Horizontal edges (left/right) contribute to row dy
    if dx <= 0 and edgeLeft.style != NONE:
        if occupiesOffset(edgeLeft.style, dy, 'horizontal'):
            contributors.add({edge: edgeLeft, axis: 'horizontal'})
    
    if dx >= 0 and edgeRight.style != NONE:
        if occupiesOffset(edgeRight.style, dy, 'horizontal'):
            contributors.add({edge: edgeRight, axis: 'horizontal'})
    
    if contributors is empty:
        return TRANSPARENT
    
    // Priority: thicker/more prominent border wins
    return pickWinner(contributors).color


function occupiesOffset(style, offset, axis) → bool:
    // Does this border style occupy the given perpendicular offset?
    switch style:
        NONE:   return false
        THIN:   return offset == 0
        THICK:  return offset in {-1, 0, +1}
        DOUBLE: return offset in {-1, +1}  // gap at 0
```

### Critical Junction Scenarios

#### Scenario 1: THICK meets THIN at a T-junction

```
THICK horizontal on top, THIN vertical going down:

    ███████████          (thick = 3 rows of pixels)
    ███████████
    ███████████
        █                (thin = 1 pixel wide, continues down)
        █

Junction 3x3 at intersection:
    ███        ← thick occupies all 3 rows at dx=-1,0,+1
    ███        ← thick occupies all 3 rows
    ███        ← thick occupies all 3 rows
     █         ← only thin at dx=0, dy=+1 (below junction)
```

The thin border's single pixel at dx=0 is **absorbed** into the thick border through the junction. No special handling needed — the thick border already fills that pixel.

#### Scenario 2: DOUBLE meets DOUBLE at a corner

```
Double horizontal (right) meets double vertical (down):

    ─   ─   ─ ┐ 
               │
    ─   ─   ─   
               │

Junction 3x3:
    dx: -1  0  +1
dy=-1: [H] [ ] [V]     H=horizontal outer line, V=vertical outer line
dy= 0: [ ] [ ] [ ]     center is always gap for both
dy=+1: [H] [ ] [V]     H=horizontal outer line, V=vertical outer line

Wait — this leaves the corner pixel (-1,-1) and (+1,+1) etc. ambiguous.
```

**Correct double-double corner rendering:**

```
For a top-right corner (double-right + double-down):

    ─ ─ ─ ╮         pixel map:
           │         (-1,-1)=H  (-1,0)=gap  (-1,+1)=V
    ─ ─ ─ ╎         ( 0,-1)=gap ( 0,0)=gap  ( 0,+1)=gap
           │         (+1,-1)=H  (+1,0)=gap  (+1,+1)=V

The OUTER lines of both borders connect at corner pixels.
The GAP channel continues through the junction.
```

This is the key insight: **the gap channel of a double border must be preserved through junctions**.

#### Scenario 3: DOUBLE meets THICK

```
Double horizontal meets thick vertical:

Junction 3x3:
    dx: -1  0  +1
dy=-1: [H] [V] [V+H]   H=horiz outer, V=thick fills all
dy= 0: [ ] [V] [V]     horiz gap row, thick fills
dy=+1: [H] [V] [V+H]   H=horiz outer, thick fills

The thick border "fills in" the gap of the double border at the junction.
This is correct — the thick border takes visual precedence through the center.
```

#### Scenario 4: THIN meets THIN at a cross

```
Junction 3x3:
    dx: -1  0  +1
dy=-1: [ ] [U] [ ]     U=up edge
dy= 0: [L] [*] [R]     L=left, R=right, *=center (all contribute)
dy=+1: [ ] [D] [ ]     D=down edge

Center pixel: multiple contributors, pick by priority (any wins, same style).
```

### Junction Pixel Resolution — Complete Truth Table

For the center pixel `(0,0)`:

| Up | Down | Left | Right | Center Pixel |
|----|------|------|-------|-------------|
| THIN | THIN | THIN | THIN | FILLED (any color) |
| THICK | any | any | any | FILLED (thick color) |
| DOUBLE | DOUBLE | DOUBLE | DOUBLE | **GAP** (all gaps align) |
| DOUBLE | THICK | any | any | FILLED (thick fills gap) |
| DOUBLE | NONE | DOUBLE | NONE | **GAP** |
| DOUBLE | THIN | DOUBLE | THIN | FILLED (thin occupies center) |

**Rule for center pixel**: It's a GAP only if ALL contributing edges are DOUBLE (or NONE). If ANY contributing edge is THIN or THICK, the center pixel is filled.

### Corner Pixels `(-1,-1)`, `(-1,+1)`, `(+1,-1)`, `(+1,+1)`

Corner pixel `(-1,-1)` (top-left of junction) is filled if:
- The UP edge is THICK or DOUBLE (occupies offset -1), OR
- The LEFT edge is THICK or DOUBLE (occupies offset -1)

If both are DOUBLE, it's filled (outer lines connect). If both are THIN, it's empty (thin only occupies offset 0).

---

## Phase 4: Rendering Pipeline

### Full Rendering Order

```
function renderAllBorders(grid, canvas):
    // Step 1: Draw all horizontal edge segments (excluding junction zones)
    for row in 0..numRows:
        for col in 0..numCols:
            border = grid.hBorders[row][col]
            if border.style == NONE: continue
            
            gx_start = colToPixelX(col) + JUNCTION_MARGIN
            gx_end   = colToPixelX(col+1) - JUNCTION_MARGIN
            gy       = rowToPixelY(row)
            
            drawHorizontalEdge(canvas, gx_start, gx_end, gy, border)
    
    // Step 2: Draw all vertical edge segments (excluding junction zones)
    for row in 0..numRows:
        for col in 0..numCols+1:
            border = grid.vBorders[row][col]
            if border.style == NONE: continue
            
            gy_start = rowToPixelY(row) + JUNCTION_MARGIN
            gy_end   = rowToPixelY(row+1) - JUNCTION_MARGIN
            gx       = colToPixelX(col)
            
            drawVerticalEdge(canvas, gx, gy_start, gy_end, border)
    
    // Step 3: Draw all junction blocks (3x3 at each grid intersection)
    for row in 0..numRows:
        for col in 0..numCols:
            renderJunction(
                colToPixelX(col), rowToPixelY(row),
                getEdgeUp(row, col),
                getEdgeDown(row, col),
                getEdgeLeft(row, col),
                getEdgeRight(row, col)
            )

// JUNCTION_MARGIN = 1 for thick/double (avoids overlapping the 3x3 block)
// For edges that are only THIN, margin = 0 (thin doesn't extend beyond center)
```

### Why Junctions Are Drawn Separately

Drawing edges and then junctions separately prevents:
1. **Double-drawing** — where a thick horizontal and thick vertical both fill the same corner pixel with different colors
2. **Gap corruption** — where a thick edge fills in the gap channel of an adjacent double edge
3. **Z-fighting** — non-deterministic rendering when two fills overlap

---

## Phase 5: Color Conflict at Junctions

When multiple edges of different colors meet at a junction pixel:

```
function pickWinner(contributors) → {color}:
    // 1. Thicker style wins
    maxWeight = max(contributors, by: styleWeight)
    heaviest = filter(contributors, weight == maxWeight)
    
    if heaviest.length == 1:
        return heaviest[0]
    
    // 2. Among equal weight: darker color wins
    darkest = min(heaviest, by: brightness(color))
    return darkest
    
    // Alternative: could use "horizontal wins" or "vertical wins" as tiebreaker
```

---

## Phase 6: Optimizations

### Dirty Rectangle Tracking

When a cell's border changes, only re-render:
- The 4 edges of that cell
- The 4 junction blocks at its corners
- Adjacent cells' edges that share those junctions

```
function onBorderChange(row, col):
    dirtyRect = expandBy(cellRect(row, col), 2)  // 2px for thick/double overhang
    // Also dirty adjacent cells' junction zones
    scheduleRepaint(dirtyRect)
```

### Batch Rendering with Canvas

For canvas-based rendering:

```javascript
function renderBordersToCanvas(ctx, grid, viewport) {
    // Only render edges/junctions visible in viewport
    const startRow = pixelToRow(viewport.top - 2);
    const endRow = pixelToRow(viewport.bottom + 2);
    const startCol = pixelToCol(viewport.left - 2);
    const endCol = pixelToCol(viewport.right + 2);
    
    // Group edges by color to minimize ctx.strokeStyle changes
    const edgesByColor = groupEdgesByColor(grid, startRow, endRow, startCol, endCol);
    
    for (const [color, edges] of edgesByColor) {
        ctx.strokeStyle = color;
        ctx.beginPath();
        for (const edge of edges) {
            // batch all same-color, same-width lines into one path
            addEdgeToPath(ctx, edge);
        }
        ctx.stroke();
    }
    
    // Junctions rendered per-pixel (ImageData for performance)
    const imageData = ctx.getImageData(viewport.left, viewport.top, viewport.width, viewport.height);
    renderJunctionsToImageData(imageData, grid, startRow, endRow, startCol, endCol);
    ctx.putImageData(imageData, viewport.left, viewport.top);
}
```

---

## Summary of Key Design Decisions

| Decision | Approach | Rationale |
|----------|----------|-----------|
| Edge storage | Top + Left per cell | No duplication, every edge stored once |
| Conflict resolution | Last-write-wins (user action) | Matches Excel behavior |
| Border centering | Centered on grid line | Equal visual weight on both sides |
| Junction rendering | Separate 3×3 pixel blocks | Prevents overlap artifacts |
| Double border gaps | Preserved through junctions unless interrupted by thick/thin | Visually correct corner connections |
| Center pixel at junction | Gap only if ALL edges are double/none | Thick/thin always fills center |
| Color priority | Wider > darker > reading-order | Matches OOXML spec |
| Performance | Dirty-rect + color batching | Efficient incremental updates |

---

## Edge Cases to Test

1. **Single cell with thick border** — all 4 corners should be clean squares
2. **Two adjacent cells, one thick one thin** — thick absorbs thin at shared edge
3. **Double border L-shape** — gap channel turns the corner cleanly
4. **Double meets thick at T-junction** — thick fills through double's gap
5. **Three different styles meeting at one junction** — up=thick, right=double, down=thin, left=none
6. **Border at sheet edge** — only 2-3 edges contribute to junction (treat missing as NONE)
7. **Same style, different colors at shared edge** — conflict resolution picks one
8. **Entire row thick border meets entire column double border** — cross-junction rendering

---

## Implementation Status

### Files

| File | Role |
|------|------|
| `lib/src/rendering/painters/cell_border_renderer.dart` | Shared border iteration & conflict resolution |
| `lib/src/rendering/painters/border_painter.dart` | Low-level edge drawing (solid, dashed, dotted, double) |
| `lib/src/core/models/border_resolver.dart` | Edge conflict resolution (width > style priority > reading order) |
| `test/rendering/painters/cell_border_renderer_test.dart` | Pixel-level tests for CellBorderRenderer |
| `test/rendering/painters/border_painter_test.dart` | Pixel-level tests for BorderPainter |

### What is implemented

- **Phase 1 (Edge Conflict Resolution)**: Fully implemented in `BorderResolver.resolve()`. Rules: non-none beats none → wider wins → higher `BorderLineStyle` index wins → later cell in reading order wins.
- **Phase 2 (Edge Rendering)**: Fully implemented in `BorderPainter.drawBorderEdge()`. Supports solid, dashed, dotted, and double line styles with configurable width and extensions.
- **CellBorderRenderer**: Extracted from duplicated code in `TilePainter._renderBorders()` and `FrozenLayer._paintCellBorders()`. Both now delegate to `CellBorderRenderer.renderBorders()` via a `getBounds` callback for coordinate transforms and a `widthScale` parameter for zoom adaptation.
- **Junction-aware extensions**: `BorderPainter.drawBorderEdge()` accepts optional `startJunctionPerpA/B` and `endJunctionPerpA/B` parameters. When provided, extension distances are computed from perpendicular border widths (visual_width / 2) instead of requiring pre-computed `startExt`/`endExt` values.
- **Gap-preserving double junctions**: `CellBorderRenderer` looks up perpendicular borders on BOTH sides of each junction (perpA = same cell, perpB = neighbor). `BorderPainter` uses these to differentiate junction types: inner sub-lines shorten when `perpA||perpB` (all junctions), outer sub-lines shorten when `perpA&&perpB` (+ junctions only). The horizontal outer's left-side extension is reduced by 1px so it starts at the cell boundary (the vertical outer already covers that corner pixel). Corner dots fill diagonal pixels at + junctions. Junction patterns: + junction = ■□■/□□□/■□■, L-corner = ■■■/■□□/■□■ (vertical outer fills through gap row).
- **FrozenLayer z-order fix**: Borders are now rendered after all cell backgrounds/content in each region (`_paintCorner`, `_paintFrozenRows`, `_paintFrozenColumns`), preventing a cell's borders from being hidden by the next cell's background.

### What is deferred

- **Phase 3 (3×3 Junction Pixel Blocks)**: The full junction rendering algorithm (iterating grid intersection points and resolving each of 9 pixels independently) is not implemented as a separate pass. Instead, the current approach uses sub-line shortening + corner dots to achieve the correct 3x3 junction pattern (■□■/□□□/■□■) for all double-double junction types (L-corners, T-junctions, + intersections). Remaining limitations:
  - Color conflicts at junction pixels (where different-colored borders meet) are resolved by draw order rather than explicit pixel priority.
- **Phase 4 (Rendering Pipeline)**: Edge segments and junctions are not drawn separately — edges are drawn full-length with extensions rather than stopping at junction margins. This is simpler and works well for the current border styles.
- **Phase 5 (Color Conflict at Junctions)**: Not separately implemented. The current `BorderResolver` handles edge-level conflicts; pixel-level color priority at junction intersections is implicit.
- **Phase 6 (Optimizations)**: Dirty-rectangle tracking and color batching are not implemented. The full cell range is re-rendered when borders change.

### Deviations from proposed algorithm

| Proposed | Actual | Why |
|----------|--------|-----|
| Top+Left edge storage per cell | Borders stored as 4-sided `CellBorders` per cell style | Matches the existing `CellStyle` data model. Conflict resolution at shared edges uses `BorderResolver`. |
| Separate junction 3×3 pixel blocks | Line extensions close corners | Simpler, handles thin/solid well. Full junction blocks needed only for complex double-double corner scenarios. |
| Draw edges then junctions separately | Edges drawn full-length with extensions | Fewer draw calls, acceptable visual results for current use cases. |