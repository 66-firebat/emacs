# MRU-tabs.el — Logic & Architecture

## Overview

MRU-tabs is a completely self-built, raw-Elisp tab line system for Emacs.
Despite loading no external tab-bar package, it provides a grouped,
MRU-ordered tab bar rendered in each window's `header-line-format`.

### Guiding principles

1. **Zero external dependencies** — All rendering, data management, and
   layout logic is built from scratch.
2. **Per-window isolation** — Each Emacs window gets its own independent
   copy of tab data (MRU order, selection, groups). Buffer switches in
   one window never affect another window's tab order.
3. **Only the focused window's data is ever updated** — `post-command-hook`
   calls `my/ct--update-window` only for `(selected-window)`. Render calls
   (`header-line-format` `:eval`) are read-only for existing windows.
4. **`copy-tree` on every read and write** — Eliminates any chance of
   cons-cell sharing between windows via Emacs's `window-parameter`.

---

## Data Architecture

### Per-window storage (`window-parameter`)

Each window stores a plist as its `'my/MRU-tabs-data` window parameter:

```elisp
(:groups    ((group-name . (buffer buffer ...)) ...)   ; all visible buffers by group
 :selected  ((group-name . buffer) ...)                 ; selected buffer per group
 :mru       ((group-name . (buffer buffer ...)) ...)    ; MRU-ordered list per group
 :scroll    nil)                                         ; reserved
```

- **Read**: `(copy-tree (window-parameter win 'my/MRU-tabs-data))` —
  deep copy guarantees the caller cannot mutate the stored data.
- **Write**: `(set-window-parameter win 'my/MRU-tabs-data (copy-tree plist))` —
  deep copy guarantees the stored data cannot be mutated by a reference
  the caller kept.
- **New windows** (no parameter yet): initialized on first render by
  calling `my/ct--update-window` from inside `my/ct--render-tabbar`.

### Data flow

```
post-command-hook
  └─ my/ct--force-update
       └─ my/ct--update-window (selected-window)
            ├─ Read:  copy-tree of window-parameter
            ├─ Mutate: fresh local lists (mapcar, append, delq, cons)
            └─ Write: copy-tree → set-window-parameter

header-line-format :eval
  └─ my/ct--eval-tabbar
       └─ my/ct--render-tabbar (window)
            ├─ Read:  copy-tree of window-parameter
            ├─ If :mru is nil (first call): initialize via my/ct--update-window
            ├─ Render: build and trim tab list (read-only)
            └─ Return: list of propertized strings
```

Key invariant: **`my/ct--update-window` is NEVER called during render**
for windows that already have data. This prevents the wrong window's
MRU from being updated during redisplay.

---

## Section-by-section breakdown

### Minor mode (`MRU-tabs-mode`)

- `MRU-tabs-mode-map` — sparse keymap for `C-<tab>` / `M-<tab>` cycling.
- `MRU-tabs-display-line-format` — customizable variable pointing to
  `header-line-format` (or an alternative variable).
- `define-minor-mode` — global minor mode that activates the keymap.

### Section 1 — Custom faces

| Face | Background | Foreground | Used for |
|---|---|---|---|
| `my/ct-tab-selected` | `#8C8C8C` | `#2b2b2b` | The currently selected tab |
| `my/ct-tab-unselected` | `#5C5C5C` | `#2b2b2b` | Non-selected tabs |
| `my/ct-group-icon` | `#ff4400` | `#2b2b2b` | Group icon + line number |
| `my/ct-overflow` | `#2b2b2b` | `#ff4400` | Overflow indicator |
| `my/ct-modified` | *inherited* | `#ff4400` | Modified-marker glyph |

**Overflow icon mapping** (`my/ct--overflow-icons`):

| Hidden tabs | Icon |
|---|---|
| 1 | ` 󰲠` |
| 2 | ` 󰲢` |
| 3 | ` 󰲤` |
| 4 | ` 󰲦` |
| 5 | ` 󰲨` |
| 6 | ` 󰲪` |
| 7 | ` 󰲬` |
| 8 | ` 󰲮` |
| 9 | ` 󰲰` |
| 10+ | ` 󰲲` |

`my/ct--overflow-str` returns `" ICON"` (space + icon = always 2 chars wide).

### Section 2 — Buffer grouping

**Category table** (`my/tab-group-categories`):

| Group | Icon | Modes |
|---|---|---|
| Code | `` | emacs-lisp, python, go, rust, C, JS/TS, nix, yaml, json, sql, ... |
| Docs | `` | org, markdown, text |
| Config | `` | conf-mode |
| Tools | `` | dired, magit, eat, vterm, help, apropos, Info |
| Buffers | `` | catch-all — any mode not matched above |

**`my/tab-group-for-buffer`** determines a buffer's group:
1. Excludes buffers with names starting with `" "` (internal/hidden) or
   named `"*scratch*"` / `"*Messages*"`.
2. Walks the category table and returns the first match by `major-mode`.
3. Falls back to `"Buffers"` if no category matches.

### Section 3 — Per-window data management

**`my/ct--get-data`** — Returns a deep copy of the window's tab-data plist.
If the window has no parameter yet, returns a fresh empty plist.

**`my/ct--put-data`** — Stores a deep copy of the given plist as the
window's parameter.

**`my/ct--update-window`** — The core data-update function:

1. **Groups**: rebuilt from scratch in `buffer-list` (`all-bufs`) order.
   Each group entry is `(group-name . (buffer-list))`.

2. **MRU**: starts from the existing stored MRU (which preserves each
   window's independent order):
   - Killed buffers are filtered out.
   - New buffers (not yet tracked by this window) are appended in
     `all-bufs` order.
   - The window's current buffer (`(window-buffer window)`) is promoted
     to the front of its group's MRU list via `delq` + `cons`.

3. **Selection**: rebuilt from groups. The window's current buffer is
   selected for its group; other groups use their first buffer.

4. **Save**: `my/ct--put-data` with a fresh plist.

This function is only ever called:
- From **`my/ct--force-update`** (on `post-command-hook`) for the
  `(selected-window)` — i.e., the window the user is actively using.
- Once from **`my/ct--render-tabbar`** for windows that have no stored
  data yet (newly created by split, pop-up, etc.).

### Section 4 — Buffer list utilities

**`my/ct--visible-buffers`** — Returns all live, non-excluded buffers in
`(buffer-list)` order. Excludes buffers whose name starts with `" "` or
named `"*scratch*"` / `"*Messages*"`.

**`my/ct--update-all-windows`** — Calls `my/ct--update-window` for every
live window. Used once at startup.

### Section 5 — Tab rendering

**`my/ct--tab-label`** — Returns a propertized string for one tab:
```
 󰐗 <bufname>          (selected —  prefix, selected face)
```
The `󰐗` modified-marker is only shown when the buffer is modified
(except for `vterm-mode` buffers, which always appear modified).

**`my/ct--render-tabbar`** — The main rendering function:

1. **Read data**: `my/ct--get-data` → plist with `:groups`, `:selected`,
   `:mru`. If `:mru` is nil (first call for a new window), calls
   `my/ct--update-window` first.

2. **Build segments**: `(mapcar (lambda (b) (cons label-str sep-str)) tabs)`
   where `tabs = (assoc cur-group (or mru groups))` (prefers MRU ordering).

3. **Width calculation & trimming**:
   - `total-w` = sum of `(string-width label) + (string-width sep)` for
     all segments.
   - `avail` = `(window-width window) - (string-width group-icon)`.
   - While `total-w + overflow-icon-width > avail` AND more than 1 tab
     remains: remove the rightmost (oldest) tab, increment `hidden`.
   - Overflow indicator width is measured via `(string-width (my/ct--overflow-str (1+ hidden)))`.

4. **Build flat list**: `[label₁, sep₁, label₂, sep₂, ..., labelₙ, sepₙ]`
   where `sepᵢ` = `"  "` propertized with tab `i`'s face.

5. **Append overflow indicator** (if `hidden > 0`):
   - If the selected tab + overflow fits: append `" 󰲠"` etc. with
     `my/ct-overflow` face.
   - If too narrow: replace entire result with `󰘕`.

**Flat list structure**: each tab contributes a `(label, trailing-sep)` pair.
Between tabs, the trailing sep of the PREVIOUS tab acts as the inter-tab
separator, taking the previous tab's face. This gives a smooth visual
transition between tabs.

### Section 6 — Group icon rendering

**`my/ct--group-icon`** — Renders the left segment of the header line:
```
      42 
```
- Category icon (e.g., `` for Tools)
- `` separator
- Line number (via `format-mode-line '("%l")`)
- `` right-arrow, all with `my/ct-group-icon` face (orange bg)

### Section 7 — `:eval` wrappers

**`my/ct--resolve-window`** — Determines which window the header-line is
being evaluated for. Uses `(current-buffer)` and `(selected-window)` to
look up the correct window. This is called once per `:eval` invocation.

**`my/ct--eval-tabbar`** and **`my/ct--eval-group-icon`** — Bind the
dynamic variable `my/ct--render-window` and call the corresponding
render functions. This variable is available for any sub-function that
needs to know which window is being rendered.

### Section 8 — Tab cycling

**`my/ct--cycle`** — Cycles through the current window's MRU list
within the current group:
- Forward: `C-<tab>` or `M-<tab>`
- Backward: `C-S-<iso-lefttab>`

Cycling uses the window's own MRU list (via `my/ct--mru`), so tabs
hidden by overflow are still reachable. `switch-to-buffer` is used
for the actual buffer switch.

### Section 9 — Activation & hooks

**Startup sequence:**
1. `MRU-tabs-mode` is activated globally.
2. `header-line-format` is set globally to:
   ```elisp
   '(:eval (my/ct--eval-group-icon) :eval (my/ct--eval-tabbar))
   ```
3. `my/ct--update-all-windows` initializes data for all windows.
4. `force-window-update` triggers the first redisplay.

**`post-command-hook`** (`my/ct--force-update`):
- Runs after every command in the selected window.
- Calls `my/ct--update-window` → promotes current buffer to MRU front.
- Calls `force-window-update` on the selected window to trigger redisplay.

**`window-deletions-functions`**:
- Cleans up the `window-parameter` when a window is deleted.

---

## Window isolation strategy

The critical bug that took the longest to find was that
`my/ct--render-tabbar` was calling `my/ct--update-window` at the start
of every render. During redisplay, `my/ct--resolve-window` could return
the **wrong** window (the focused window instead of the window being
rendered), causing that window's MRU to be updated with the wrong
buffer. This made buffer switches in one window "leak" into other
windows' tab orders.

The fix: **`my/ct--update-window` is only called from
`post-command-hook`**, where `(selected-window)` always refers to the
window the user is actively using. The render path is read-only.

For new windows (created by split, pop-up, etc.), a one-time
initialization call happens inside `my/ct--render-tabbar` when it
detects `:mru` is nil. After that, the renderer never writes.

---

## Tab overflow & trimming

When tabs are wider than the available window space (accounting for the
group icon), rightmost non-current tabs are hidden:

1. Pre-compute total width of all tab segments.
2. While `total + overflow-indicator > avail` and more tabs remain:
   remove the rightmost tab, increment hidden counter.
3. After trimming: build the flat list, append the overflow icon.
4. If even the selected tab + overflow doesn't fit: show `󰘕` instead.

The overflow indicator is `" 󰲠"` through `"󰲲"` depending on count
(1 space + 1 Nerd Font icon = always exactly 2 chars wide).

The trimming condition measures `(string-width (my/ct--overflow-str (1+ hidden)))`
to account for the overflow indicator that will be appended after trimming.
