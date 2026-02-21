# Spreadsheet Formula Cell Reference Updating Behavior

## Overview

When editing a formula in spreadsheet applications (Excel, Google Sheets, LibreOffice Calc, etc.), cell references within the formula are **automatically updated** when the user interacts with the spreadsheet using mouse, touch, or keyboard navigation. This is a fundamental UX pattern to replicate when implementing spreadsheet-like formula editing.

---

## Core Behavior

### Formula Edit Mode

When a user begins editing a formula (by pressing `=`, `F2`, or clicking into the formula bar), the spreadsheet enters **formula edit mode**. In this mode:

- The formula being edited is displayed in the formula bar
- Existing cell references within the formula are highlighted with **color-coded borders** on the referenced cells/ranges
- User interactions with cells update the formula rather than navigating away

### Mouse / Touch Interaction During Formula Editing

**Single Cell Click**

When the user clicks or taps a cell while editing a formula:
- The cell reference (e.g., `A1`, `$B$3`) is inserted at the current cursor position in the formula
- If a reference already exists at the cursor position (e.g., the cursor is within `A1`), that reference is **replaced** with the newly selected cell

**Range Selection by Drag**

When the user clicks and drags across multiple cells:
- A range reference is inserted (e.g., `A1:C5`)
- If a reference exists at the cursor position, it is replaced with the new range

**Cross-Sheet Range Selection**

When the user clicks a **different sheet tab** and then selects a cell or range:
- The formula is updated with a sheet-qualified reference: `SheetName!A1` or `SheetName!A1:C5`
- The formula bar reflects the update in real time as the user makes the selection
- Returning focus to the original sheet does not reset or cancel the selection

**Touch Behavior**

On touch devices, the same rules apply:
- Tap to select a single cell reference
- Tap and drag to select a range
- Tap a sheet tab then tap/drag to select a cross-sheet reference

---

## Reference Types Inserted

| Action | Example Result |
|--------|---------------|
| Click cell on same sheet | `B3` |
| Drag across cells on same sheet | `B3:D7` |
| Click cell on different sheet | `Sheet2!B3` |
| Drag across cells on different sheet | `Sheet2!B3:D7` |
| Shift+click to extend range | Extends existing range reference |

---

## Visual Feedback During Editing

- **Color coding**: Each distinct cell reference or range in the formula is assigned a unique color. The corresponding cell/range on the sheet is highlighted with a matching colored border.
- **Marching ants**: Some applications show an animated dashed border ("marching ants") around the selected range.
- **Formula bar update**: The formula bar updates in real time as selections change.
- **Reference replacement**: When the cursor is positioned within an existing reference token, clicking a new cell replaces that token entirely rather than appending.

---

## Keyboard Behavior (for completeness)

- Arrow keys in formula edit mode move the active cell reference, updating the formula
- `Shift+Arrow` extends a range selection
- `F4` cycles through absolute/relative reference modes (`A1` → `$A$1` → `A$1` → `$A1` → `A1`)
- `Enter` or `Tab` confirms the formula
- `Escape` cancels editing and restores the original formula

---

## Implementation Notes for Claude Code

When building a spreadsheet component with formula editing:

1. **Track edit mode state**: Distinguish between normal navigation mode and formula edit mode.
2. **Intercept pointer events**: In formula edit mode, cell clicks should update the formula, not navigate.
3. **Tokenize the formula**: Parse the formula to identify reference tokens so the cursor position can determine which reference to replace.
4. **Handle sheet switching**: When the user switches sheet tabs during formula editing, do not commit or cancel the formula — remain in edit mode and qualify new selections with the sheet name.
5. **Sync visual highlights**: Keep colored range highlights in sync with the formula tokens.
6. **Support range dragging**: Track `mousedown` on a cell, `mousemove` across cells, and `mouseup` to finalize the range.
7. **Touch events**: Mirror mouse events with `touchstart`, `touchmove`, `touchend`.

---

## Application Support

| Application | Mouse Select | Touch Select | Cross-Sheet Reference |
|-------------|-------------|--------------|----------------------|
| Microsoft Excel (Desktop) | ✅ | ✅ | ✅ |
| Microsoft Excel (Web) | ✅ | ✅ | ✅ |
| Google Sheets | ✅ | ✅ | ✅ |
| LibreOffice Calc | ✅ | ✅ | ✅ |
| Apple Numbers | ✅ | ✅ | ✅ |

---

## Example Formula Edit Flow

1. User clicks cell `D1` and types `=`
2. User clicks cell `A1` → formula becomes `=A1`
3. User types `+`
4. User clicks the "Q2 Data" sheet tab → formula becomes `=A1+'Q2 Data'!`
5. User clicks cell `B5` on the Q2 Data sheet → formula becomes `=A1+'Q2 Data'!B5`
6. User presses `Enter` → formula is committed and user returns to original sheet

> **Note**: Sheet names containing spaces or special characters are automatically wrapped in single quotes (e.g., `'Q2 Data'!B5`).

---

## Implementation Status

The following features from this spec are implemented in the `worksheet` package via `FormulaReferenceConfig`:

| Feature | Status |
|---------|--------|
| Formula mode detection (`=` prefix) | Implemented |
| Click cell to insert reference | Implemented |
| Drag to insert range reference | Implemented |
| Replace existing reference at cursor | Implemented |
| Color-coded borders on referenced cells | Implemented |
| Marching ants on active reference | Implemented |
| Arrow keys insert/move references | Implemented |
| F4 cycles absolute/relative modes | Implemented |
| Configurable via `FormulaReferenceConfig` | Implemented |
| Cross-sheet references | N/A (single-sheet widget) |
| Shift+click to extend range | Not yet implemented |
| Formula bar | Not yet implemented |