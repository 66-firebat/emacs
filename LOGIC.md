# Centaur Tabs Configuration Logic

## Overview

This document describes **all** the logic in `centaur-tabs.el` (the user config) and its
interactions with the underlying `centaur-tabs` package (source: `centaur-tabs.el`,
`centaur-tabs-functions.el`, `centaur-tabs-elements.el`, `centaur-tabs-interactive.el`)
and core Emacs primitives.

---

## Table of Contents

1. [Architecture: How Centaur Tabs Renders](#1-architecture-how-centaur-tabs-renders)
2. [Initialization & Mode Toggle](#2-initialization--mode-toggle)
3. [Tab Data Structures (Tabset System)](#3-tab-data-structures-tabset-system)
4. [Buffer Grouping System](#4-buffer-grouping-system)
5. [Tab Ordering & Per-Window MRU](#5-tab-ordering--per-window-mru)
6. [Tab Label Rendering](#6-tab-label-rendering)
7. [Tab Line Format Construction](#7-tab-line-format-construction)
8. [Color Gradient & Separator Application](#8-color-gradient--separator-application)
9. [Overflow Truncation](#9-overflow-truncation)
10. [Group Icon + Line Number Segment](#10-group-icon--line-number-segment)
11. [Git Branch Cache](#11-git-branch-cache)
12. [Live Update via post-command-hook](#12-live-update-via-post-command-hook)
13. [Keyboard Navigation](#13-keyboard-navigation)
14. [Per-Window State Cleanup](#14-per-window-state-cleanup)
15. [Tab Cycling & Scope](#15-tab-cycling--scope)
16. [Advice System & Cleanup](#16-advice-system--cleanup)

---

## 1. Architecture: How Centaur Tabs Renders

Centaur tabs works by **replacing the Emacs header-line-format** (or tab-line-format)
with its own custom format. The core chain is:

```
header-line-format ──> centaur-tabs-header-line-format
                            │
                     ┌──────┘
                     ▼
          (:eval (centaur-tabs-line))
                     │
                     ▼
          centaur-tabs-line()
                     │
                     ├── centaur-tabs-current-tabset(t)  →  resolve current tabset
                     ├── centaur-tabs-template(tabset)   →  cached render
                     └── centaur-tabs-line-format(tabset) →  build render
                              │
                              └── centaur-tabs-line-tab(tab)  →  per-tab string
                                       │
                                       ├── separator (left)
                                       ├── left-edge-margin
                                       ├── icon (optional)
                                       ├── tab-label (via centaur-tabs-tab-label-function)
                                       ├── close-button / modified-marker
                                       └── separator (right)
```

**Key Emacs concepts:**

- `header-line-format` / `tab-line-format` — buffer-local variables controlling what
  appears at the top of each window. Semantics match `mode-line-format`.

- `:eval` — a mode-line construct that calls a function at redisplay time to produce
  a string/list.

- `propertize` — applies text properties (face, keymap, help-echo) to strings; these
  survive through header-line rendering.

- `force-window-update` — marks windows for redisplay on the next frame refresh.

- `format-mode-line` — evaluates a mode-line format spec and returns the resulting
  string (used for `%l` line-number extraction).

---

## 2. Initialization & Mode Toggle

### `centaur-tabs-mode` (global minor mode)

Defined in `centaur-tabs.el`. When activated:

1. Saves the current default value of `centaur-tabs-display-line-format` into
   `centaur-tabs--global-hlf` (so it can be restored on disable).

2. Calls `centaur-tabs-init-tabsets-store()` — creates an obarray (a vector of 31
   slots) named `centaur-tabs-tabsets` to hold all tabsets as interned symbols, and
   creates a special symbol `centaur-tabs-tabsets-tabset` used for "groups of
   groups" display.

3. Runs `centaur-tabs-init-hook`, which triggers `centaur-tabs-buffer-init()`:

   - Sets `centaur-tabs-current-tabset-function` → `centaur-tabs-buffer-tabs`
   - Sets `centaur-tabs-tab-label-function` → `centaur-tabs-buffer-tab-label`
   - Sets `centaur-tabs-select-tab-function` → `centaur-tabs-buffer-select-tab`
   - Registers hooks: `after-focus-change-function`, `window-buffer-change-functions`,
     `after-save-hook`, `first-change-hook`, `kill-buffer-hook`
   - Advises: `undo`, `undo-tree-undo-1`, `undo-tree-redo-1`, `load-theme`

4. Sets `centaur-tabs-display-line-format` globally to `centaur-tabs-header-line-format`
   which is `(:eval (centaur-tabs-line))`.

### In the user config:

```elisp
(centaur-tabs-mode t)
(centaur-tabs-headline-match)
```

`centaur-tabs-headline-match()` sets the `centaur-tabs-display-line` face (either
`header-line` or `tab-line` face) to use `centaur-tabs-unselected` background,
removing box/overline/underline decorations — making the header line blend in.

### `centaur-tabs-display-line-format` indirection:

This variable is either `'header-line-format` or `'tab-line-format`, depending on
which Emacs version is running. Its *symbol value* is the *name* of the actual
format variable. The user config uses:

```elisp
(let ((fmt-var (symbol-value 'centaur-tabs-display-line-format)))
  (set-default fmt-var ...))
```

This reads `centaur-tabs-display-line-format` → `'header-line-format`, then
`set-default` on `header-line-format` sets it globally.

---

## 3. Tab Data Structures (Tabset System)

### Tabsets

A **tabset** is a symbol interned in the `centaur-tabs-tabsets` obarray. Each
tabset has:

- **Symbol name** = group name (e.g., "Code", "Docs", "Project: /path")
- **Symbol value** = list of tab cons cells: `((BUFFER . TABSET) ...)`
- **Property `start`** = index of first visible tab (for horizontal scrolling)
- **Cache** (in `centaur-tabs-display-hash` hash table, keyed by tabset name as
  string) stores:
  - `'select` → currently selected tab cons cell
  - `'template` → cached rendered header-line template (list of strings)

### Tabs

A **tab** is a cons cell: `(BUFFER . TABSET)` where:
- `car` = the buffer object
- `cdr` = the tabset symbol it belongs to

### Key functions:

| Function | Purpose |
|----------|---------|
| `centaur-tabs-make-tabset(NAME &rest OBJECTS)` | Create a new tabset, intern it, populate with tabs |
| `centaur-tabs-get-tabset(NAME)` | Look up tabset by name via `intern-soft` |
| `centaur-tabs-tabs(TABSET)` | Get the list of tab cons cells (`symbol-value`) |
| `centaur-tabs-selected-tab(TABSET)` | Get cached selected tab |
| `centaur-tabs-select-tab(TAB TABSET)` | Mark tab as selected, invalidate template cache |
| `centaur-tabs-add-tab(TABSET OBJECT)` | Add a buffer to a tabset (insert after selected) |
| `centaur-tabs-delete-tab(TAB)` | Remove a tab, auto-select next |
| `centaur-tabs-current-tabset(UPDATE)` | Get/set the current tabset via `current-tabset-function` |
| `centaur-tabs-view(TABSET)` | Return visible tabs (from `start` index onward) |

---

## 4. Buffer Grouping System

### Overview

Buffers are partitioned into named groups. Each group becomes its own tabset.
Grouping is determined by `centaur-tabs-buffer-groups-function` (default:
`centaur-tabs-buffer-groups`).

### Default grouping (in centaur-tabs source)

`centaur-tabs-buffer-groups()` returns a list with one group name:

1. **Project name** — if `centaur-tabs-project-name()` returns a value (via
   `project-current`), it uses `"Project: /path/to/project"`.
2. **"Magit"** — for magit-*-mode buffers
3. **"Shell"** — derived from `shell-mode`
4. **"EShell"** — derived from `eshell-mode`
5. **"Dired"** — derived from `dired-mode`
6. **"OrgMode"** — `org-mode`, `org-agenda-mode`, `diary-mode`
7. **Custom** — if `centaur-tabs-custom-buffer-groups` is set, call it
8. **"Elisp"** — derived from `emacs-lisp-mode`
9. **"Emacs"** — any buffer whose name starts with `*`
10. **`centaur-tabs-get-group-name(BUF)`** — fallback using hash cache

### User config custom grouping

The user defines their own `my/tab-group-categories`:

```elisp
'(("Code"    ""   emacs-lisp-mode lisp-mode python-mode ...)
  ("Docs"    ""   org-mode markdown-mode text-mode)
  ("Config"  ""   conf-mode)
  ("Tools"   ""   dired-mode magit-mode eat-mode ...)
  ("Buffers" ""))   ;; catch-all
```

The function `my/tab-group-for-buffer(&optional BUFFER)` returns the group name:

1. Skip buffers starting with space or named `*scratch*` / `*Messages*`
2. Walk categories in order, check if `major-mode` is in the mode list
3. If no match, return `"Buffers"` (catch-all)

The user then sets:
```elisp
(setq centaur-tabs-buffer-groups-function #'my/tab-group-for-buffer)
```

**Important:** the user's grouping function returns a **single group name**
(a string), not a list. This works because centaur-tabs source wraps it:
```elisp
(if centaur-tabs-buffer-groups-function
    (funcall centaur-tabs-buffer-groups-function)
  '(centaur-tabs-common-group-name))
```

### How `centaur-tabs-buffer-update-groups()` works

Called every time tabs need refresh:

1. Gets buffer list via `centaur-tabs-buffer-list-function`
2. For each buffer, computes group(s) via `centaur-tabs-buffer-groups-function`
3. Builds cache `centaur-tabs--buffers` = `((BUFFER NAME (GROUPS...)) ...)`
4. Compares with previous cache — only updates if changed
5. For new buffers/groups: creates tabsets or adds tabs
6. For removed buffers: deletes tabs and empty tabsets

### Buffer list filtering via `centaur-tabs-hide-tab`

The function `centaur-tabs-hide-tab(BUF)` determines if a buffer should appear
as a tab:

- Hides if `window-dedicated-p`
- Hides if buffer name starts with any prefix in `centaur-tabs-excluded-prefixes`
  (e.g., `"*epc"`, `"*helm"`, `" *which"`, `"*lsp"`, etc.)
- Hides magit buffers that have no file extension

Results are cached in `centaur-tabs-hide-hash`.

---

## 5. Tab Ordering & Per-Window MRU

### Default: `centaur-tabs-buffer-list-function`

Default value is `centaur-tabs-buffer-list()` which filters:
- Current buffer
- Buffers visiting files
- Non-space-prefixed buffers

The order follows `(buffer-list)` which is MRU — the most recently selected
buffer is first.

### User config: per-window MRU ordering

The user replaces the default buffer list function:

```elisp
(setq centaur-tabs-buffer-list-function #'my/tab-buffer-list)
```

`my/tab-buffer-list()`:

1. Gets the current buffer and its group
2. Filters `(buffer-list)` to only include buffers in the same group
3. Returns `(CUR . remaining)` with current buffer first, followed by other
   buffers in `(buffer-list)` order

### Per-window independent ordering (advanced)

The user implements true per-window tab ordering via:

```elisp
(defvar my/centaur-tabs--window-state (make-hash-table :test 'eq)
  "Hash table window → ((GROUP-NAME . (BUFFER ...)) ...)")
```

Key: window object. Value: list of `(GROUP . buffers-list)` conses.

**`my/centaur-tabs--reorder-tabset-mru`** — around advice on `centaur-tabs-line`:

1. Gets the global tabset for the current group
2. Looks up per-window state for the selected window
3. If no state exists, initializes it from the global tabset
4. Syncs: adds new buffers from global, removes killed buffers
5. Sorts: current buffer first, rest in `(buffer-list)` order
6. Converts buffer list back to tab cons cells
7. Temporarily **replaces the global tabset value** with the per-window order
8. Calls the original `centaur-tabs-line` for rendering
9. Debug message logs the per-window buffer order

### `my/centaur-tabs--sort-tabset-mru` (unused helper)

Defined but never called in the config — a simpler MRU sort that directly
manipulates the tabset value.

---

## 6. Tab Label Rendering

### Protocol

`centaur-tabs-tab-label-function` is called with one argument: a tab cons cell
`(BUFFER . TABSET)`. It must return a string.

### Default: `centaur-tabs-buffer-tab-label`

Returns `" <buffer-name>"` with optional truncation to `centaur-tabs-label-fixed-length`.

### User: `my/centaur-tabs-tab-label`

```elisp
(defun my/centaur-tabs-tab-label (tab)
  "Return a label for TAB.  Modified buffers get 󰐗 prefix (in #ff4400)."
  (let* ((tabset ...) (selected-p ...)
         (buf (car tab)) (bufname (buffer-name buf))
         (modified ...)
         (prefix (if modified (propertize "󰐗 " 'face '(:foreground "#ff4400")) "")))
    (if selected-p
        (format " %s%s" prefix bufname)
      (format " %s%s " prefix bufname))))
```

Features:
- **Modified indicator**: If the buffer is modified and not in `vterm-mode`,
  prepends `󰐗` in `#ff4400` (orange-red)
- **Selected tab** gets `` prefix (a powerline arrow)
- **Unselected tabs** get space padding

Note: the user sets this via:
```elisp
(setq centaur-tabs-tab-label-function 'my/centaur-tabs-tab-label)
```

But also wraps `centaur-tabs-line` in `my/centaur-tabs-line` to trim trailing
spaces from tab strings.

---

## 7. Tab Line Format Construction

### `centaur-tabs-line-format(tabset)`

Returns a list (the header-line template) with 5 elements:

```
(TAB-COUNT NAVIGATION-BUTTONS TABS-LIST RIGHT-FILLER NEW-TAB-BUTTON)
```

1. **`TAB-COUNT`**: `" [%d/%d] "` if `centaur-tabs-show-count` is on
2. **`NAVIGATION-BUTTONS`**: down/back/forward buttons (graphic display only)
3. **`TABS-LIST`**: list of propertized strings, each produced by
   `centaur-tabs-line-tab(tab)`
4. **`RIGHT-FILLER`**: `"% "` propertized with padding face — fills remaining width
5. **`NEW-TAB-BUTTON`**: `" + "` if `centaur-tabs-show-new-tab-button` is set

The function also handles **scroll tracking**: if `centaur-tabs--track-selected`
is non-nil, it scrolls the view to ensure the selected tab is visible, using
a temp buffer to measure text width via `vertical-motion`.

### `centaur-tabs-line-tab(tab)`

Produces a single tab string by concatenating (in order):

1. **Left separator** — XPM image via powerline (e.g., `powerline-bar-right`)
2. **Active bar** — thin XPM bar on the left (if `centaur-tabs-set-bar` is `'left`)
3. **Left edge margin** — `centaur-tabs-left-edge-margin`
4. **Left close button** — if `centaur-tabs-set-left-close-button`
5. **Icon** — via `centaur-tabs-icon()` (all-the-icons or nerd-icons)
6. **Tab label** — via `centaur-tabs-tab-label-function`
7. **Jump identifier** — ace-jump key character overlay
8. **Close button or modified marker**
9. **Right edge margin** — `centaur-tabs-right-edge-margin`
10. **Right separator**

### `centaur-tabs-line()` — the top-level eval function

Called via `(:eval (centaur-tabs-line))` in the header-line format. It:

1. Checks if the current buffer should hide tabs (via `centaur-tabs-hide-tab-cached`
   or `centaur-tabs-hide-predicate`). If so, sets `header-line-format` to nil.
2. Calls `centaur-tabs-current-tabset(t)` to refresh the current tabset
3. Returns cached template if available, otherwise calls `centaur-tabs-line-format`

### User config: wrapping `centaur-tabs-line`

The user defines `my/centaur-tabs-line` which calls `centaur-tabs-line` then
strips trailing spaces from all tab strings:

```elisp
(defun my/centaur-tabs-line ()
  (let ((fmt (centaur-tabs-line)))
    (when (consp fmt)
      (let ((tabs (nth 2 fmt)))
        (when (consp tabs)
          (setcar (nthcdr 2 fmt)
                  (mapcar (lambda (s) (if (stringp s) (string-trim-right s) s)) tabs)))))
    fmt))
```

This is then inserted into the header-line format:

```elisp
(set-default fmt-var
             `((:eval (my/centaur-tabs-group-icon))
               (:eval (my/centaur-tabs-line))))
```

The header-line format is: **[group-icon] [tab-bar]**.

---

## 8. Color Gradient & Separator Application

### `my/centaur-tabs--apply-gradient` — around advice on `centaur-tabs-line-format`

This is the **most complex** piece of the config. It wraps `centaur-tabs-line-format`
to apply uniform colors and add powerline-style separator characters using Nerd
Fonts instead of XPM images.

### Step-by-step:

1. **Call original**: `(funcall orig-fn tabset)` → get the template list
2. **Extract** the tab elements from `(nth 2 result)` — this is the list of
   propertized tab strings
3. **Apply colors** to each tab string:
   - Background: `#5C5C5C` (unselected), `#8C8C8C` (selected)
   - Foreground: `#2b2b2b` (dark, same for both)
   - Strip trailing spaces before propertizing
4. **Build result with separator characters**:
   - Between each tab: `` (powerline right-pointing triangle)
   - After each tab: ` ` (a small right-pointing chevron)
   - Coloring matches the adjacent tab's background
5. **Return** the rebuilt template with `(nth 2 result)` replaced

The original `centaur-tabs-line-format` returns a list like:
```
(" 1/5 " "" (TAB1 TAB2 TAB3 ...) "% " " + ")
```

The advice modifies the third element (TABS list) to inject separator strings
between tabs.

---

## 9. Overflow Truncation

### Condition: `my/centaur-tabs-overflow-adapt` is non-nil (default t)

When the total tab width exceeds available terminal width:

1. **Calculate available width**:
   ```elisp
   (floor (* (window-width) my/centaur-tabs-width-factor))
   ```
   `window-width` returns the terminal width in columns. The factor defaults to
   1.0 but can be adjusted.

2. **Measure group icon width** via `(string-width (my/centaur-tabs-group-icon))`

3. **Drop tabs from the right** one at a time:
   - Remove the last tab's separator + label + trailing chevron (3 elements)
   - Decrement `n-dropped` counter
   - Continue until total fits or only 1 tab remains

4. **Show overflow indicator**:
   - Uses Nerd Font digit characters: `󰲠` (1), `󰲢` (2), ... `󰲰` (9), `󰲲` (10+)
   - If ≤9 tabs dropped, uses the corresponding Nerd Font digit
   - If ≥10 dropped, uses `󰲲`
   - Displayed in `my/centaur-tabs-overflow-face` (orange on dark background)

---

## 10. Group Icon + Line Number Segment

### `my/centaur-tabs-group-icon`

Returns a propertized string like: `     42  `

Components:
1. **Group icon**: looked up from `my/tab-group-categories` (e.g., `` for Code,
   `` for Docs, `` for Config, `` for Tools, `` for Buffers)
2. **Line number**: via `my/centaur-tabs--line-number`
3. **Separator**: `` then ` ` at the end

Face: `(:background "#ff4400" :foreground "#2b2b2b" :weight bold)` — orange
background, dark foreground, bold.

### `my/centaur-tabs--line-number`

Uses `format-mode-line` with `"%l"` spec to get the current line number:

```elisp
(defun my/centaur-tabs--line-number (buf)
  (if (eq buf (current-buffer))
      (let ((live (format-mode-line '("%l"))))
        (puthash buf live my/centaur-tabs--line-cache)
        live)
    (gethash buf my/centaur-tabs--line-cache "󱃓")))
```

- For the **current buffer**: evaluates live via `format-mode-line`
- For **other buffers**: returns cached value, or `󱃓` (flame/fallback)

Line numbers are cached per-buffer in `my/centaur-tabs--line-cache` (hash table,
`eq` test on buffer objects).

---

## 11. Git Branch Cache

### `my/centaur-tabs--branch-cache`

Hash table mapping project path (string) → `"branch:hash"` string.

### `my/centaur-tabs--invalidate-branch-cache`

Called at the start of `my/centaur-tabs-group-name`:

```elisp
(defun my/centaur-tabs--invalidate-branch-cache ()
  (unless (eq (current-buffer) my/centaur-tabs--last-buffer)
    (clrhash my/centaur-tabs--branch-cache)
    (setq my/centaur-tabs--last-buffer (current-buffer))))
```

Clears the cache when the current buffer changes.

### `my/centaur-tabs--git-info(PROJECT-PATH)`

Runs `git -C PROJECT-PATH rev-parse --abbrev-ref HEAD` and
`git -C PROJECT-PATH rev-parse --short HEAD` via `call-process`.

Returns `"branch:hash"` or `"󱃓"` on failure (including detached HEAD, empty branch).

### `my/centaur-tabs-group-name`

Called from `my/centaur-tabs-group-icon` indirectly — builds the group label:

- If the group name matches `"Project: <path>"`:
  - Calls `my/centaur-tabs--git-info` for that path
  - Shows `  branch:hash ` or ` 󱃓 `
- Otherwise:
  - Maps group name to an icon: Elisp→``, Magit→``, Shell→``,
    Dired→``, Org→``, Emacs→``, default→``
  - Shows ` icon group-name `

Result is propertized with `my/centaur-tabs-group-face`.

---

## 12. Live Update via post-command-hook

### `my/centaur-tabs--force-update`

```elisp
(defun my/centaur-tabs--force-update ()
  (when (and centaur-tabs-mode (not (minibufferp)))
    (centaur-tabs-buffer-update-groups)
    (let ((tabset (centaur-tabs-current-tabset)))
      (when tabset
        (centaur-tabs-set-template tabset nil)))
    (force-window-update (selected-window))))

(add-hook 'post-command-hook #'my/centaur-tabs--force-update)
```

This runs **after every command**:

1. Recomputes buffer groups (detects new/killed buffers)
2. Invalidates the template cache for the current tabset (forces re-render)
3. Marks the selected window for update

This ensures:
- Line numbers update constantly
- Modified markers appear immediately
- Branch info refreshes on buffer switch
- Per-window tab order updates

---

## 13. Keyboard Navigation

```elisp
(define-key centaur-tabs-mode-map (kbd "<M-tab>") 'centaur-tabs-forward)
(define-key centaur-tabs-mode-map (kbd "C-<tab>") 'centaur-tabs-forward)
(define-key centaur-tabs-mode-map (kbd "C-S-<iso-lefttab>") 'centaur-tabs-backward)
```

- `M-TAB` / `C-TAB` → next tab
- `C-S-TAB` → previous tab

The cycling functions `centaur-tabs-forward` / `centaur-tabs-backward` respect
`centaur-tabs-cycle-scope` which is set to `'tabs` in the user config (navigate
only through visible tabs of the current group, not through groups).

---

## 14. Per-Window State Cleanup

```elisp
(defvar my/centaur-tabs--window-state (make-hash-table :test 'eq))

(defun my/centaur-tabs--on-window-deleted (window)
  (remhash window my/centaur-tabs--window-state))

(add-hook 'window-deletions-functions #'my/centaur-tabs--on-window-deleted)
```

`window-deletions-functions` (Emacs 29+) is called during redisplay when windows
are about to be deleted. Each function receives the window being deleted.

This ensures that when a window is closed, its per-window tab order state is
removed from the hash table, preventing memory leaks.

---

## 15. Tab Cycling & Scope

### `centaur-tabs-cycle(&optional BACKWARD)`

1. Gets current tabset and "groups tabset" (selected tabs of all groups)
2. Checks `centaur-tabs-cycle-scope`:
   - `'tabs` — cycle through visible tabs of current group
   - `'groups` — cycle through groups (select first/last tab of each group)
   - `nil` — try tabs first, then groups
3. Calls `centaur-tabs-buffer-select-tab` which does `switch-to-buffer`

### User config: scope = `'tabs`

```elisp
(setq centaur-tabs-cycle-scope 'tabs)
```

This means `C-TAB` cycles only through buffers in the current group, not
switching to other groups.

---

## 16. Advice System & Cleanup

The config installs **two around-advice** functions:

| Advice | Target | Purpose |
|--------|--------|---------|
| `my/centaur-tabs--reorder-tabset-mru` | `centaur-tabs-line` | Per-window MRU ordering |
| `my/centaur-tabs--apply-gradient` | `centaur-tabs-line-format` | Apply colors + separators |

And **cleans up** stale advice from previous reloads:

```elisp
(advice-remove 'centaur-tabs-line #'my/centaur-tabs--trim-tab-trailing)
(advice-remove 'centaur-tabs-line-format #'my/centaur-tabs--trim-tabs)
(advice-remove 'centaur-tabs-line #'my/centaur-tabs--reorder-tabset)
```

These are old names from earlier iterations — removed to prevent duplication
when the config is reloaded.

### Additional cleanup:

```elisp
(centaur-tabs-set-template (centaur-tabs-current-tabset) nil)
(force-window-update (selected-window))
```

Clears the cached template and forces the selected window to redraw immediately.

---

## Appendix: Key Emacs APIs Used

| API | Purpose |
|-----|---------|
| `header-line-format` / `tab-line-format` | The render target — mode-line format list |
| `force-window-update` | Mark window for redisplay |
| `propertize` | Apply text properties (face, keymap, help-echo) |
| `format-mode-line` | Evaluate mode-line format spec (e.g., `"%l"` for line number) |
| `call-process` | Run git commands synchronously |
| `window-width` | Get terminal width in columns |
| `string-width` | Measure displayed width of a string |
| `post-command-hook` | Run after every command (live update) |
| `window-deletions-functions` | Hook when windows are deleted (cleanup) |
| `buffer-list` | Get all buffers in MRU order |
| `selected-window` | Get the currently selected window |
| `sxhash` | Debug — hash a window for identification |
| `cl-position`, `cl-find`, `cl-loop` | Generic sequence operations |
| `add-function` / `remove-function` | For `after-focus-change-function` |
| `advice-add` / `advice-remove` | Around-advice wrapping |
| `defface` | Define custom faces |
| `defvar` with hash-table | Caches (window state, line numbers, branch info) |
| `make-hash-table :test 'eq` | Hash by identity (buffers, windows) |
| `make-hash-table :test 'equal` | Hash by value (project paths) |
| `puthash` / `gethash` / `clrhash` / `remhash` | Hash table operations |
| `string-trim-right` / `string-suffix-p` | String manipulation |
| `butlast` / `nthcdr` / `setcar` / `setcdr` / `nconc` | List manipulation |
| `nreverse` / `delq` / `memq` / `assoc` | List/search operations |
| `easy-menu-create-menu` / `x-popup-menu` | Context menus (right-click) |
