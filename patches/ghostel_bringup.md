# ghostel_bringup — Replace Eat with Ghostel, 1:1

**Status:** PLANNING — mapping complete, implementation in progress
**Date:** 2026-07-23

---

## Objective

Replace the `eat` terminal emulator with `ghostel` across the entire Emacs
configuration, preserving **every feature** at 1:1 parity:

- Indexed terminal spawning (1  PID, 2  PID, …)
- Mode-aware M-t dispatcher (grease → spawn in root dir, kill grease after)
- Zoxide directory travel (eaterz)
- Compose buffer (C-c C-c sends to terminal)
- Dired toggle from terminal's working directory (C-e)
- Consult-buffer eat source (numeric input spawns terminal)
- MRU-tabs "Eat" group
- Pane wrap glyphs
- Doom modeline git-segment skip
- Grease ↔ terminal cd-on-quit integration
- Evil insert-state cursor snap
- Terminal width correction for statuscolumn line-prefix
- Semi-char non-bound keys (M-t, M-r, M-k, M-g, M-i, M-z, M-w, M-W, M-e, M-h, M-l)

---

## Ghostel API Equivalents

| Eat API | Ghostel API | Notes |
|---------|-------------|-------|
| `derived-mode-p 'eat-mode` | `derived-mode-p 'ghostel-mode` | Direct substitution |
| `eat-mode-hook` | `ghostel-mode-hook` | Direct substitution |
| `eat-enable-shell-integration` | `ghostel-shell-integration` | Already set in init.el |
| `eat-default-input-mode` | `ghostel-initial-input-mode` | Already set: `'semi-char` |
| `eat-term-scrollback-size` | `ghostel-scrollback-size` | Already set: `nil` |
| `eat-semi-char-non-bound-keys` | `ghostel-semi-char-non-bound-keys` | Same vector format `[?\e ?t]` |
| `eat-semi-char-mode-map` | `ghostel-semi-char-mode-map` | Direct substitution |
| `eat--semi-char-mode-map` | `ghostel--semi-char-mode-map` | Internal keymap |
| `eat-terminal` (buffer-local) | `ghostel--term` (buffer-local) | Terminal object |
| `eat-term-parameter term 'eat--process` | `ghostel--process` (buffer-local) | Process object |
| `eat-term-display-cursor` | `ghostel--cursor-position` | Returns `(col . row)` |
| `eat-term-send-string` / `eat--send-string` | `ghostel-send-string` | Public API |
| `eat-exec` | `ghostel` command (see below) | Spawning |
| `eat-term-resize` advice | TBD | See Width Correction below |
| `window-adjust-process-window-size-function` | TBD | See Width Correction |
| `evil-ghostel-mode` minor mode | `evil-ghostel-mode` | Already configured in init.el |
| `eat-term-parameter` (generic getter) | ghostel buffer-local vars | `ghostel--process`, `ghostel--term`, etc. |

---

## Ghostel Spawning API (verified from source at ghostel.el L5293)

```elisp
(defun ghostel (&optional arg)
  (let* ((fresh (and arg (not (numberp arg))))     ;; t, C-u = always fresh
         (identity (cond (fresh nil)
                         ((numberp arg) (format "%s<%d>" ghostel-buffer-name arg))
                         (t ghostel-buffer-name))) ;; no arg = *ghostel*
         (existing (and (not fresh)                ;; fresh=t => this is nil
                        (ghostel--find-buffer-by-identity identity))))
    (if existing
        (pop-to-buffer existing ...)    ;; just switches to existing
      (with-current-buffer buffer
        (ghostel--start-process)        ;; reads default-directory
        (ghostel--apply-initial-input-mode)))
    buffer))
```

| Call | Behaviour |
|------|-----------|
| `(ghostel)` | Creates `*ghostel*` **or switches** if it already exists |
| `(ghostel t)` | **Always** fresh buffer — skips existence check entirely |
| `(ghostel 3)` | Goes to `*ghostel*<3>` or creates it with that identity |

Key facts from source:
- **No `:cwd` keyword** — `ghostel--start-process` reads `default-directory`
  from the buffer, and `generate-new-buffer` inherits the caller's dynamic binding.
- **`ghostel-buffer-name`** (defcustom, default `"*ghostel*"`) is the base name
  passed to `ghostel--create` -> `generate-new-buffer`.
- **`ghostel-other`** is a switching command, not a spawner — not useful here.

Our spawning pattern:
```elisp
(let ((default-directory cwd)                   ;; set CWD
      (ghostel-buffer-name (format "%d " index))) ;; base name for create
  (ghostel t))  ;; t = always fresh, never switches
;; Then rename to "N  <PID>" after process is live
```

---

## Files to Modify (Complete Inventory)

### 1. NEW: `ghostel/ghostfire.el` — Replaces `eat/eaterz.el`

**Contains everything currently in `eat/eaterz.el`:**
- `use-package ghostel` + `use-package evil-ghostel` (moved from init.el)
- Indexed spawning: `my/ghostel-next-available`, `my/ghostel-new`
- Mode-aware dispatch: `my/ghostel-new-dispatch-alist`, `my/ghostel-new-dispatch`
- Grease handler: `my/ghostel-new-from-grease` with kill-grease-on-spawn
- Ghostfire (eaterz port): zoxide + consult + embark pipeline
- Compose buffer: `my/ghostel-compose` / send / cancel
- Semi-char non-bound keys block

### 2. `init.el` — Terminal section

Changes:
```diff
- (my/load-module "eat/eaterz.el")   ;; Terminal emulator inside Emacs
+ (my/load-module "ghostel/ghostfire.el")  ;; Ghostel terminal config
```

The existing `use-package ghostel` and `use-package evil-ghostel` blocks
move *into* `ghostel/ghostfire.el` (consolidated).

### 3. `keybinds.el` — Extensive eat references

| Current | Change |
|---------|--------|
| `M-t` -> `my/eat-new-dispatch` | -> `my/ghostel-new-dispatch` |
| `M-z` -> `my/zoxide-travel-dispatch` | -> update `eat-mode` check to `ghostel-mode` |
| `C-e` -> `my/dired-from-eat` | -> update `eat-mode` check to `ghostel-mode` |
| `my/eat-compose` / send / cancel | -> `my/ghostel-compose` variants |
| `my/eat-buffer-list` | -> `my/ghostel-buffer-list` |
| `my/eat-spawn-at-index` | -> `my/ghostel-spawn-at-index` |
| Eat non-bound keys dolist | -> move to `ghostel/ghostfire.el` |
| `C-c C-m` -> `my/eat-compose` | -> `my/ghostel-compose` |

### 4. `consult-buffer.el` — Eat source

Changes:
- `my/consult-eat-source` -> `my/consult-ghostel-source`
- `my/consult-source-buffer-no-eat` -> `my/consult-source-buffer-no-ghostel`
- Replace `eat-mode` checks with `ghostel-mode`
- Replace `my/eat-spawn-at-index` with `my/ghostel-spawn-at-index`
- Replace `my/eat-buffer-list` with `my/ghostel-buffer-list`

### 5. `MRU-tabs.el` — Tab group

```diff
- ("Eat"     ""   eat-mode)
+ ("Ghostel" ""   ghostel-mode)
```

### 6. `panes.el` — Wrap glyph hooks

```diff
- (dolist (hook '(eat-mode-hook vterm-mode-hook))
+ (dolist (hook '(ghostel-mode-hook vterm-mode-hook))
```

### 7. `doom-modeline.el` — Git segment skip

**No change needed.** `my/gitsigns-str` uses `(not buffer-file-name)` — a
generic guard that works for all non-file buffers regardless of terminal
backend. Backend-agnostic by design.

### 8. `grease.el` — Grease <-> Terminal integration

Changes:
- Rename `grease-eat-cd-on-quit` -> `grease-ghostel-cd-on-quit`
- `grease--cd-origin-eat` -> `grease--cd-origin-ghostel`
- Replace `eat-mode` check -> `ghostel-mode`
- Replace `eat-term-parameter` + `eat--send-string` -> `ghostel-send-string`

### 9. `custom.el` — Package list

```diff
- eat
+ ghostel
```

### 10. DELETE: `eat-firemacs.el` — Already done (stale duplicate)

### 11. DELETE: `eat/eaterz.el` — Replaced by `ghostel/ghostfire.el`

---

## Width Correction Analysis

**Eat's problem:**
`eat-term-resize` uses `window-max-chars-per-line` which doesn't account for
the statuscolumn's 7-char `line-prefix`. The advice subtracts the prefix.

**Ghostel:**
Ghostel's rendering is handled by the native Zig module, not by Elisp-side
width calculation. The native module reads the Emacs window/font metrics
directly. We need to verify whether ghostel has the same issue.

**Decision:**
1. First, test ghostel with statuscolumn enabled — does it render correctly?
2. If ghostel handles this natively (likely since it reads window metrics
   from the native side), remove the width correction entirely.
3. If ghostel has the same issue, we'll need to find the equivalent hook.

---

## Evil Cursor Snap Analysis

**Eat:** `my/eat-snap-cursor-on-insert` hooks into `evil-insert-state-entry-hook`.

**Ghostel:** `evil-ghostel-mode` (already configured) handles cursor sync
automatically — it syncs point with terminal cursor on evil state transitions
via `evil-ghostel--reset-cursor-point` and `evil-ghostel--cursor-to-point`.

**Decision:** Remove the manual snap — evil-ghostel covers it.

---

## Zoxide Travel (Eaterz) Port

The eaterz system is a self-contained pipeline:
- `zoxide query -ls` -> consult async -> embark actions -> cd in terminal

**Ghostel equivalents:**
- `eat-term-parameter eat-terminal 'eat--process` -> `ghostel--process`
- `eat--send-string proc "cd DIR\n"` -> `ghostel-send-string "cd DIR\n"`
- `derived-mode-p 'eat-mode` -> `derived-mode-p 'ghostel-mode`

The consult/embark/vertico pipeline stays identical. Only the terminal send
mechanism changes.

---

## Ghostel Non-Bound Keys

Ghostel uses `ghostel-semi-char-non-bound-keys` (same format as eat's):
```elisp
(add-to-list 'ghostel-semi-char-non-bound-keys [?\e ?t])  ;; M-t
```

The keymap names change:
- `eat-semi-char-mode-map` -> `ghostel-semi-char-mode-map`
- `eat--semi-char-mode-map` -> `ghostel--semi-char-mode-map`

Moved into `ghostel/ghostfire.el` (was in keybinds.el for eat).

---

## Implementation Order

### Phase 1: Core ghostel config (ghostel/ghostfire.el) [DONE]
1. `use-package ghostel` + `use-package evil-ghostel` (moved from init.el)
2. `my/ghostel-next-available` — index scanning
3. `my/ghostel-new` — spawn at index, "N  <PID>" naming
4. `my/ghostel-spawn-at-index` — helper for consult-buffer
5. `my/ghostel-buffer-list` — list all ghostel-mode buffers

### Phase 2: Mode-aware dispatch [DONE]
6. `my/ghostel-new-dispatch-alist`
7. `my/ghostel-new-from-grease` (with kill-on-spawn)
8. `my/ghostel-new-dispatch`

### Phase 3: Zoxide travel (eaterz port) [DONE]
9. Full ghostfire system — consult/embark/zoxide pipeline

### Phase 4: Compose buffer [DONE]
10. `my/ghostel-compose` / send / cancel

### Phase 5: Cross-file integration [NEXT]
11. `keybinds.el` — all eat references updated
12. `consult-buffer.el` — eat source -> ghostel source
13. `MRU-tabs.el` — group name
14. `panes.el` — hook change
15. `grease.el` — cd-on-quit rename and API update
16. `custom.el` — package list

### Phase 6: Width correction
17. Test ghostel rendering with statuscolumn
18. Remove width correction if ghostel handles natively
19. If needed, find ghostel equivalent hook

### Phase 7: Cleanup
20. `init.el` — update terminal section
21. Delete `eat/eaterz.el`
22. Update patch docs

---

## Open Questions

### Q1. Ghostel buffer naming — resolved

We override `ghostel-buffer-name` dynamically before calling `(ghostel t)`.
Ghostel uses `generate-new-buffer` which gets the base name from the
`ghostel-buffer-name` defcustom. After the process starts, we rename
to include the PID.

### Q2. Width correction — needs testing

### Q3. `ghostel-semi-char-non-bound-keys` format — needs verification

Expected to use the same `[?\e ?t]` vector format as eat. The `ghostfire.el`
code assumes this and includes a `(boundp ...)` guard.

### Q4. Grease `grease-eat-cd-on-quit` — rename needed

Recommend renaming to `grease-ghostel-cd-on-quit`.

### Q5. `my/dired-from-eat` function name — rename suggested

Recommend: `my/dired-from-terminal` (backend-agnostic).

---

## Test Checklist

1. `M-t` from any non-grease buffer -> spawns ghostel at index 1, `default-directory`
2. `M-t` again -> spawns ghostel at index 2
3. Kill terminal 1, `M-t` -> reuses index 1
4. `M-t` from grease buffer -> spawns in `grease--root-dir`, kills grease buffer
5. `M-t` from grease with unsaved changes -> saves first, then spawns + kills
6. Buffer naming: `"1  <PID>"`, `"2  <PID>"`, etc.
7. `M-z` in ghostel buffer -> zoxide directory travel works (cd + clear)
8. `C-e` from ghostel -> opens dired at terminal's `default-directory`
9. `C-e` from dired -> closes dired, returns to ghostel
10. `M-i` -> consult-buffer shows "Ghostel" section with existing terminals
11. Type a number in consult-buffer -> spawns ghostel at that index
12. Tab bar shows "Ghostel" group with terminal buffers
13. Pane wrap glyphs work correctly in ghostel buffers
14. Modeline git segment suppressed for ghostel buffers
15. Grease quit -> `cd` sent to originating ghostel terminal
16. Non-bound keys (M-t, M-r, M-k, etc.) pass through to Emacs
17. Evil insert-state cursor sync works (evil-ghostel)
18. Terminal renders correctly with statuscolumn (width test)
19. Compose buffer: `my/ghostel-compose` -> write -> `C-c C-c` sends to ghostel
