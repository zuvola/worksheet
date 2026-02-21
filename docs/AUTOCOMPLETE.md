# Formula Autocomplete Dropdown — Implementation Spec

## Overview

This document describes the formula autocomplete behaviour found in Google Sheets and Excel so it can be replicated in a spreadsheet-like UI.

---

## Trigger Conditions

The autocomplete dropdown should appear when **all** of the following are true:

1. A cell is in **edit mode** (user double-clicked or pressed `F2` / started typing).
2. The cell content **starts with `=`** (formula mode).
3. The cursor is positioned on a **function name token** — i.e. the characters immediately before the cursor form a letter sequence that is not yet inside parentheses of a completed function call.

### Character-level trigger
- After `=` is typed, begin monitoring subsequent keystrokes.
- On each **letter key** (`[A-Za-z]`), evaluate the current token under the cursor.
- If the token matches one or more known function names (prefix match), show the dropdown.
- If the token matches nothing, hide the dropdown.
- On `Backspace` / `Delete`, re-evaluate and update or hide accordingly.

### Formula bar button
- A small **function icon / "fx" button** sits to the left of the formula bar.
- Clicking it while a cell is selected puts the cell into formula-edit mode AND opens a function picker / insert-function dialog (slightly different from inline autocomplete — it's a modal with categories and descriptions).
- For inline autocomplete specifically, the dropdown is triggered by typing, not by this button.

---

## Tokenisation

To know *what* to autocomplete, parse the formula string up to the cursor position and extract the **current token**:

```
formula:  =SUM(A1) + AVE|   ← cursor here (|)
token:    "AVE"
```

Rules:
- A token starts after any of: `=`, `(`, `,`, `+`, `-`, `*`, `/`, `^`, `&`, `<`, `>`, `{`, space.
- A token ends at the cursor position.
- A token is only autocomplete-eligible if it contains **only letters** (no digits, no `$`, no `:` etc.).

---

## Matching Logic

```
matches = ALL_FUNCTIONS.filter(fn => fn.startsWith(token.toUpperCase()))
matches = matches.sort()           // alphabetical
```

- Case-insensitive prefix match.
- Include both built-in functions and any user-defined named functions.
- Limit visible items to **8–10** at a time; scroll for the rest.

---

## Dropdown UI

### Position
- Appear **directly below** the cell being edited, aligned to the left edge of the cell.
- If the cell is near the bottom of the viewport, flip the dropdown **above** the cell.

### Contents (per row)
| Element | Details |
|---|---|
| Function icon | Small `ƒx` or category icon |
| Function name | Bold, with the matching prefix **highlighted** |
| Brief signature | e.g. `SUM(number1, [number2], …)` in muted text |

### Keyboard navigation
| Key | Action |
|---|---|
| `↑` / `↓` | Move selection up / down |
| `Tab` or `Enter` | Accept selected item — replace token with function name + `(` |
| `Escape` | Dismiss dropdown, keep typed text |
| Any letter/backspace | Continue typing, re-filter list |

### Mouse
- Hover highlights a row.
- Click accepts the item (same as Tab/Enter).

---

## Acceptance Behaviour

When a suggestion is accepted:

1. Replace the current token in the formula string with the full function name in **UPPERCASE**.
2. Append an opening parenthesis `(`.
3. Move cursor inside the parentheses.
4. Immediately show the **function tooltip** (argument hint) — see below.

Example:
```
Before:  =ave         cursor at end
After:   =AVERAGE(    cursor here
```

---

## Function Argument Tooltip (secondary UX)

After a function name and `(` exist, show a small tooltip **below the cell** with the function signature. Highlight the **current argument** as the user types commas.

```
AVERAGE( number1, [number2], … )
         ^^^^^^^  ← bold/highlighted = current argument
```

This is separate from the autocomplete dropdown but closely related — it activates when the cursor is inside `()` of a known function.

---

## Data Source

Maintain a functions registry:

```js
const FUNCTIONS = [
  {
    name: "SUM",
    signature: "SUM(number1, [number2], …)",
    description: "Adds all the numbers in a range of cells.",
    argCount: { min: 1, max: Infinity }
  },
  // ... all supported functions
]
```

At minimum, include the ~100 most common spreadsheet functions. The full Excel/Sheets list has 400+.

---

## State Machine (simplified)

```
IDLE
  → user types "=" in cell          → FORMULA_MODE

FORMULA_MODE
  → letter typed, token matches     → SHOW_DROPDOWN
  → letter typed, no match          → HIDE_DROPDOWN
  → Escape / click outside          → IDLE
  → Enter (no dropdown open)        → IDLE (commit cell)

SHOW_DROPDOWN
  → ↑↓ keys                         → UPDATE_SELECTION
  → Tab / Enter                      → ACCEPT → FORMULA_MODE
  → Escape                           → FORMULA_MODE (dropdown closed)
  → letter / backspace               → re-filter → SHOW_DROPDOWN or HIDE_DROPDOWN
```

---

## Implementation Notes for Claude Code

- **Debounce** the filter call by ~50 ms to avoid thrashing on fast typing.
- Use a **virtual list** for the dropdown if the functions list is large (400+ items).
- The dropdown should be rendered in a **portal** / absolutely positioned element outside the cell DOM tree to avoid clipping by `overflow: hidden` on table containers.
- Track cursor position via `selectionStart` on the input/contenteditable, not just the end of the string — users may edit mid-formula.
- When the cell is a `<textarea>` or `contenteditable`, listen on `input` and `keydown` events; do **not** use `onChange` alone as it fires after the fact.
- Dismiss the dropdown on `blur` of the cell (with a small delay to allow click events on the dropdown to fire first).

---

## Edge Cases

| Scenario | Expected behaviour |
|---|---|
| Token inside a string `="SU"` | No autocomplete — inside quotes |
| Token after a sheet ref `=Sheet2!SU` | Autocomplete on `SU` still |
| Nested function `=IF(SU` | Autocomplete on `SU` |
| Already-complete function `=SUM(` | No name autocomplete; show argument tooltip |
| Numbers/symbols only `=123` | No autocomplete |
| Named ranges with same prefix | Optionally include named ranges in the list with a different icon |

---

## Implementation Status

### Implemented

- **Data model**: `FormulaFunction` (name, signature, description) and `FormulaAutocompleteConfig` (function list, maxVisibleItems, minChars, custom matcher)
- **Token extraction**: `FormulaFunctionTokenizer.extractToken()` — extracts the alphabetic token at cursor position, handles quotes, operators, digits
- **Matching**: `FormulaFunctionMatcher.match()` — case-insensitive prefix match, alphabetically sorted results
- **Controller**: `AutocompleteController` — manages visibility, matches, selection index, keyboard navigation (selectNext/selectPrevious), accept/dismiss
- **Dropdown widget**: `AutocompleteDropdown` — ListView with bold prefix highlighting, muted signatures, selected-item highlighting, tap-to-select via Listener
- **Keyboard integration**: Up/Down navigate, Tab/Enter accept (inserts `FN(`), Escape dismisses (stays in edit mode)
- **Text/cursor integration**: Autocomplete re-evaluates on every text change and cursor movement
- **Worksheet integration**: `Worksheet.formulaAutocompleteConfig` parameter, dropdown positioned below editing cell (flips above if near bottom)

### Not Yet Implemented

- Function argument tooltip (secondary UX — highlight current argument inside parentheses)
- Debounce on fast typing (not needed for typical function list sizes)
- Virtual list for 400+ functions (standard ListView handles this adequately)
- Named range suggestions
- Category icons in dropdown