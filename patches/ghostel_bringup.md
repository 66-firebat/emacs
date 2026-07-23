# ghostel_bringup — Replace Eat with Ghostel, 1:1

**Status:** PLANNING — mapping complete, implementation pending
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
| `derive-mode-p 'eat-mode` | `derived-mode-p 'ghostel-mode` | Direct substitution |
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
| `eat-exec` | `ghostel` command or `(ghostel :cwd DIR)` | Programmatic spawn |
| `eat-term-resize` advice | TBD — ghostel may not need this | See §Width Correction below |
| `window-adjust-process-window-size-function` | TBD | See §Width Correction |
| `evil-ghostel-mode` minor mode | `evil-ghostel-mode` | Already configured in init.el |
| `eat-term-parameter` (generic getter) | ghostel buffer-local vars | `ghostel--process`, `ghostel--term`, etc. |

---

## Ghostel Spawning API

Ghostel's `ghostel` command supports programmatic spawn:

```elisp
(ghostel)                          ;; Interactive — new buffer, prompts for name
(ghostel :cwd "/some/dir")         ;; Programmatic — spawn in directory
(ghostel :cwd "/some/dir" :name "my-term")  ;; With explicit buffer name
```

The `ghostel-buffer-name-function` (defcustom) controls buffer naming.
Default format: `*ghostel*<N>` or title-based. We'll override for our
`"N  PID"` scheme.

---

## Files to Modify (Complete Inventory)

### 1. NEW: `ghostel-firemacs.el` — Replaces `eat/eaterz.el`

**Contains everything currently in `eat/eaterz.el` + `eat-firemacs.el`:**
- `use-package ghostel` configuration
- Terminal width correction (or removal — see below)
- Evil insert cursor snap (or removal — evil-ghostel may handle)
- Indexed spawning: `my/ghostel-next-available`, `my/ghostel-new`
- Mode-aware dispatch: `my/ghostel-new-dispatch-alist`, `my/ghostel-new-dispatch`
- Grease handler: `my/ghostel-new-from-grease` with kill-grease-on-spawn
- **Eaterz → Zoxide travel port** (full consult+embark pipeline using ghostel APIs)

### 2. `init.el` — Terminal section

Changes:
```diff
- (my/load-module "eat/eaterz.el")   ;; Terminal emulator inside Emacs
+ (my/load-module "ghostel-firemacs.el")  ;; Ghostel terminal emulator config
```

The existing `use-package ghostel` and `use-package evil-ghostel` blocks
move *into* `ghostel-firemacs.el` (consolidated).

### 3. `keybinds.el` — Extensive eat references

| Current | Change |
|---------|--------|
| `M-t` → `my/eat-new-dispatch` | → `my/ghostel-new-dispatch` |
| `M-z` → `my/zoxide-travel-dispatch` | → update `eat-mode` check to `ghostel-mode` |
| `C-e` → `my/dired-from-eat` | → update `eat-mode` check to `ghostel-mode` |
| `my/eat-compose` / `my/eat-compose-send` / `my/eat-compose-cancel` | → `my/ghostel-compose` variants |
| `my/eat-buffer-list` | → `my/ghostel-buffer-list` |
| `my/eat-spawn-at-index` | → `my/ghostel-spawn-at-index` |
| Eat non-bound keys dolist | → Ghostel non-bound keys dolist |
| `C-c C-m` → `my/eat-compose` | → `my/ghostel-compose` |

### 4. `consult-buffer.el` — Eat source

Changes:
- `my/consult-eat-source` → `my/consult-ghostel-source`
- `my/consult-source-buffer-no-eat` → `my/consult-source-buffer-no-ghostel`
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

**No change needed.** `my/gitsigns-str` already returns nil for non-file buffers
via `(not buffer-file-name)` — a generic guard that works for eat, ghostel, dired,
and any terminal backend. The comment "not dired, eat, etc." is just commentary;
the actual code has no mode-specific check at all. Backend-agnostic by design.

### 8. `grease.el` — Grease ↔ Terminal integration

Changes:
- Rename `grease-eat-cd-on-quit` → `grease-ghostel-cd-on-quit`
- `grease--cd-origin-eat` → `grease--cd-origin-ghostel`
- Replace `eat-mode` check → `ghostel-mode`
- Replace `eat-term-parameter` + `eat--send-string` → `ghostel-send-string`

### 9. `custom.el` — Package list

```diff
- eat
+ ghostel
```

### 10. DELETE: `eat-firemacs.el` — Stale duplicate, never loaded

`eat-firemacs.el` is a stale/outdated copy of `eat/eaterz.el`. Both provide
`eat-firemacs`, but init.el only loads `eat/eaterz.el`. The file serves no
purpose — safe to delete now, before any ghostel work begins.

### 11. DELETE: `eat/eaterz.el` — Replaced by `ghostel-firemacs.el`

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
3. If ghostel has the same issue, we'll need to find the equivalent hook
   (possibly `ghostel--term-resize` or similar internal).

---

## Evil Cursor Snap Analysis

**Eat:**
`my/eat-snap-cursor-on-insert` hooks into `evil-insert-state-entry-hook`,
calls `eat-term-display-cursor` and `goto-char`.

**Ghostel:**
`evil-ghostel-mode` (already configured) handles cursor synchronization
automatically — it syncs point ↔ terminal cursor on evil state transitions
via `evil-ghostel--reset-cursor-point` (normal→insert) and
`evil-ghostel--cursor-to-point` (insert→normal).

**Decision:** Remove the manual snap — evil-ghostel covers it.

---

## Zoxide Travel (Eaterz) Port

The eaterz system is a self-contained pipeline:
- `zoxide query -ls` → consult async → embark actions → cd in terminal

**Ghostel equivalents:**
- `eat-term-parameter eat-terminal 'eat--process` → `ghostel--process`
- `eat--send-string proc "cd DIR\n"` → `ghostel-send-string "cd DIR\n"`
- `derived-mode-p 'eat-mode` → `derived-mode-p 'ghostel-mode`

The consult/embark/vertico pipeline stays identical. Only the terminal send
mechanism changes.

---

## Ghostel Non-Bound Keys

Ghostel uses `ghostel-semi-char-non-bound-keys` (same format as eat's):
```elisp
(add-to-list 'ghostel-semi-char-non-bound-keys [?\e ?t])  ;; M-t
```

The keymap names change:
- `eat-semi-char-mode-map` → `ghostel-semi-char-mode-map`
- `eat--semi-char-mode-map` → `ghostel--semi-char-mode-map`

The dolist in keybinds.el gets updated with ghostel equivalents.

---

## Implementation Order

### Phase 1: Core ghostel config (ghostel-firemacs.el)
1. `use-package ghostel` + `use-package evil-ghostel` (move from init.el)
2. `my/ghostel-next-available` — index scanning
3. `my/ghostel-new` — spawn at index, "N  PID" naming
4. `ghostel-buffer-name-function` — custom buffer naming
5. `my/ghostel-spawn-at-index` — helper for consult-buffer
6. `my/ghostel-buffer-list` — list all ghostel-mode buffers

### Phase 2: Mode-aware dispatch
7. `my/ghostel-new-dispatch-alist`
8. `my/ghostel-new-from-grease` (with kill-on-spawn)
9. `my/ghostel-new-dispatch`

### Phase 3: Zoxide travel (eaterz port)
10. Port entire eaterz system — consult/embark/zoxide pipeline
11. `my/zoxide-travel-dispatch` updated

### Phase 4: Compose buffer
12. `my/ghostel-compose` / `my/ghostel-compose-send` / `my/ghostel-compose-cancel`

### Phase 5: Cross-file integration
13. `keybinds.el` — all eat references updated
14. `consult-buffer.el` — eat source → ghostel source
15. `MRU-tabs.el` — group name
16. `panes.el` — hook change
17. `grease.el` — cd-on-quit rename and API update
18. `custom.el` — package list

### Phase 6: Width correction
19. Test ghostel rendering with statuscolumn
20. Remove width correction if ghostel handles natively
21. If needed, find ghostel equivalent hook

### Phase 7: Cleanup
22. `init.el` — update terminal section
23. Delete `eat-firemacs.el` (already deletable now — stale duplicate)
24. Delete `eat/eaterz.el`
25. Update patch docs
26. Remove `eat` from `elpa/` (optional — will be unused but harmless)

---

## Open Questions

### Q1. Ghostel buffer naming — "N  PID" format

Ghostel uses `ghostel-buffer-name-function`. We'll set a custom function
that reads `ghostel--process` for PID and an index counter for the prefix.

**Question:** Can we intercept ghostel's buffer creation to name it "N  PID"
before it's displayed, or do we need to create+rename? The eat approach
creates a "N  waiting" buffer first, then renames after the process starts.

**Tentative answer:** Same approach — create with temp name, spawn,
rename after process is live.

### Q2. Width correction — needed or not?

See analysis above. **Test first.**

### Q3. `ghostel-semi-char-non-bound-keys` format

Eat uses `[?\e ?t]` vectors. Does ghostel use the exact same format?
**Likely yes** — ghostel's input modes are eat-inspired.

### Q4. Grease `grease-eat-cd-on-quit` — rename or keep alias?

The defcustom and function names reference "eat". We should rename:
- `grease-eat-cd-on-quit` → `grease-terminal-cd-on-quit` (generic)
- Or keep separate ghostel variant with eat→ghostel rename

**Recommendation:** Rename to ghostel-specific. Eat is being removed.

### Q5. `my/dired-from-eat` function name

Rename to `my/dired-from-terminal` (generic) or `my/dired-from-ghostel`?

**Recommendation:** `my/dired-from-terminal` — generic, works for any future
terminal backend changes.

---

## Test Checklist

1. `M-t` from any non-grease buffer → spawns ghostel at index 1, `default-directory`
2. `M-t` again → spawns ghostel at index 2
3. Kill terminal 1, `M-t` → reuses index 1
4. `M-t` from grease buffer → spawns in `grease--root-dir`, kills grease buffer
5. `M-t` from grease with unsaved changes → saves first, then spawns + kills
6. Buffer naming: `"1  <PID>"`, `"2  <PID>"`, etc.
7. `M-z` in ghostel buffer → zoxide directory travel works (cd + clear)
8. `C-e` from ghostel → opens dired at terminal's `default-directory`
9. `C-e` from dired → closes dired, returns to ghostel
10. `M-i` → consult-buffer shows "Ghostel" section with existing terminals
11. Type a number in consult-buffer → spawns ghostel at that index
12. Tab bar shows "Ghostel " group with terminal buffers
13. Pane wrap glyphs work correctly in ghostel buffers
14. Modeline git segment suppressed for ghostel buffers
15. Grease quit → `cd` sent to originating ghostel terminal
16. Non-bound keys (M-t, M-r, M-k, etc.) pass through to Emacs
17. Evil insert-state cursor sync works (evil-ghostel)
18. Terminal renders correctly with statuscolumn (width test)
19. Compose buffer: `my/ghostel-compose` → write → `C-c C-c` sends to ghostel
