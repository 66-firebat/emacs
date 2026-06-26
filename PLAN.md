# Plan: Fix Per-Window MRU Tab Ordering

## Problem Statement

When cycling tabs, the tab line does **not** respect MRU (Most Recently Used)
ordering. After switching from tab A → tab B, tab A should appear immediately
to the **right** of tab B (because A was the tab you were just on before B).
This is not happening.

Additionally, each window must maintain its **own independent** MRU tab order.
One window's tab switches must never affect another window's tab display order.

---

## Root-Cause Analysis

After tracing the full code flow through the config, the centaur-tabs package
source, and the Emacs redisplay engine, I identified **four interacting bugs**:

### Bug 1: `centaur-tabs-buffer-update-groups` alphabetically re-sorts

In `centaur-tabs-functions.el`, `centaur-tabs-buffer-update-groups` does this:

```elisp
(let ((bl (sort
           (mapcar ... (funcall centaur-tabs-buffer-list-function))
           #'(lambda (e1 e2)
               (string-lessp (nth 1 e1) (nth 1 e2))))))
```

Even though `my/tab-buffer-list` returns buffers in a meaningful order (current
buffer first, rest in `(buffer-list)` order), the outer `sort` **re-sorts them
alphabetically by buffer name**. The initial tabset is created in alphabetical
order, not MRU order.

**Impact**: The very first tab display is alphabetical, not MRU.

### Bug 2: The advice **mutates the global tabset symbol**

In `my/centaur-tabs--reorder-tabset-mru`:

```elisp
(set tabset (copy-tree pw-tabs))
```

This mutates the globally-interned tabset symbol. The tabset interned in
`centaur-tabs-tabsets` is shared across ALL windows. When Window 1 renders the
`"Code"` group, it overwrites the global `"Code"` tabset with Window 1's MRU
order. When Window 2 then renders `"Code"`, it sees Window 1's order — not its
own.

**Impact**: Per-window state is immediately corrupted by cross-window mutation.
When Window 2 initializes its per-window state, it starts from the WRONG order
(Window 1's order, not the canonical one).

### Bug 3: `my/tab-buffer-list` conflicts with the advice

`my/tab-buffer-list` already returns buffers with the **current buffer first**
(the rest in `(buffer-list)` order, which is global MRU). This function is set
as `centaur-tabs-buffer-list-function`. It's called by
`centaur-tabs-buffer-update-groups` to build/update the global tabset.

The advice then re-sorts **again** — but the global tabset was already built
with "current first" ordering. This means:

- When the cache matches (no buffer add/remove), `centaur-tabs-buffer-update-groups`
  skips rebuilding, and the tabset keeps whatever order the advice set last time.
- When the cache DOESN'T match (buffer added/removed), the tabset is rebuilt
  from `my/tab-buffer-list` (which returns current-first), then the advice
  re-sorts again.

The two mechanisms are fighting each other. The advice's work gets partially
undone.

### Bug 4: Aggressive `post-command-hook` fights the advice

`my/centaur-tabs--force-update` runs `centaur-tabs-buffer-update-groups` on
**every** command, which calls `my/tab-buffer-list`. Even though the cache
check prevents tabset rebuilding when no buffers changed, the cache IS
recomputed and compared — introducing unnecessary work. More critically, this
prepares the global tabset state BEFORE the advice runs, and the two may
conflict if the cache has a subtle mismatch.

---

## Desired Behavior

Given tabs [A, B, C, D] in order, the window's tab line should update as
follows:

| Action | Displayed Order | Explanation |
|--------|-----------------|-------------|
| Start (A selected) | `[A* B C D]` | Initial MRU: A most recent, rest in buffer-list order |
| Switch to B | `[B* A C D]` | B most recent, A was the MRU before B |
| Switch to D | `[D* B A C]` | D most recent, B was MRU before D, A before B |
| Switch back to A | `[A* D B C]` | A most recent, D was MRU before A, B before D |

Separate windows must maintain INDEPENDENT orders. If Window 1 is [A, B, C]
and Window 2 is [D, E], switching tabs in Window 2 must never reorder
Window 1's display.

---

## Proposed Fix: Simplified Per-Window Buffer List

### Core idea

Eliminate the advice entirely. Instead, have `my/tab-buffer-list` return
per-window ordered buffers **directly**, and force the centaur-tabs tabset to
rebuild from this function on every redisplay by invalidating its internal
cache.

### Changes needed

#### 1. Replace `my/tab-buffer-list` → `my/pw-tab-buffer-list`

New function that:

1. Looks up the selected window's per-window buffer order from
   `my/centaur-tabs--window-state`.
2. If no state exists for this window+group, initializes it from the global
   `(buffer-list)` (filtered to the current group).
3. Moves the **current buffer** to the **front** of the per-window list.
4. Removes killed buffers, adds new live buffers (from `(buffer-list)`) to
   the end.
5. Saves the updated state back to the hash table.
6. Returns the ordered list.

```elisp
(defun my/pw-tab-buffer-list ()
  "Return buffers for the selected window's group, in per-window MRU order."
  (let* ((win (selected-window))
         (cur (current-buffer))
         (group (my/tab-group-for-buffer cur))
         (state (gethash win my/centaur-tabs--window-state))
         (entry (and state group (assoc group state)))
         (pw-bufs (and entry (cdr entry))))
    (when group
      ;; Initialize from global buffer-list on first access
      (unless pw-bufs
        (setq pw-bufs
              (delq nil
                    (mapcar (lambda (b)
                              (when (and (buffer-live-p b)
                                         (eq (my/tab-group-for-buffer b) group))
                                b))
                            (buffer-list))))
        (my/pw--save-state win group pw-bufs))
      ;; Sync: add new buffers, remove killed ones
      (dolist (b (buffer-list))
        (when (and (buffer-live-p b)
                   (eq (my/tab-group-for-buffer b) group)
                   (not (memq b pw-bufs)))
          (setq pw-bufs (nconc pw-bufs (list b)))))
      (setq pw-bufs (cl-remove-if-not #'buffer-live-p pw-bufs))
      ;; MRU: move current buffer to front
      (when (memq cur pw-bufs)
        (setq pw-bufs (cons cur (delq cur pw-bufs))))
      ;; Save and return
      (my/pw--save-state win group pw-bufs)
      pw-bufs)))
```

#### 2. Add `my/pw--save-state` helper

```elisp
(defun my/pw--save-state (win group bufs)
  "Store BUFS as the per-window order for WIN in GROUP."
  (let* ((state (gethash win my/centaur-tabs--window-state))
         (entry (and state (assoc group state))))
    (if entry
        (setcdr entry bufs)
      (let ((new-entry (cons group bufs)))
        (if state
            (setcdr state (cons new-entry (cdr state)))
          (puthash win (list new-entry) my/centaur-tabs--window-state))))))
```

#### 3. Remove the `my/centaur-tabs--reorder-tabset-mru` advice

Delete:
```elisp
(advice-remove 'centaur-tabs-line #'my/centaur-tabs--reorder-tabset)
(advice-add 'centaur-tabs-line :around #'my/centaur-tabs--reorder-tabset-mru)
```

Also remove the unused `my/centaur-tabs--sort-tabset-mru` helper.

#### 4. Force tabset rebuild on every redisplay

The problem: `centaur-tabs-buffer-update-groups` caches results and skips
rebuilding if buffer membership hasn't changed. But we NEED the tabset order
to reflect `my/pw-tab-buffer-list` on every redisplay.

Solutions (choose one):

**Option A** (simplest): Set `centaur-tabs--buffers` to `nil` in the
`post-command-hook` handler, before calling the update. This forces a full
rebuild:

```elisp
(defun my/centaur-tabs--force-update ()
  (when (and centaur-tabs-mode (not (minibufferp)))
    (setq centaur-tabs--buffers nil)          ;; ← invalidate cache
    (centaur-tabs-buffer-update-groups)
    (let ((tabset (centaur-tabs-current-tabset)))
      (when tabset
        (centaur-tabs-set-template tabset nil)))
    (force-window-update (selected-window))))
```

**Option B** (smarter): Set `centaur-tabs--buffers` to nil only when the
selected window has changed since the last command. Otherwise, the per-window
state already has the correct order and the tabset just needs a template clear.

**Option C** (most efficient): Instead of invalidating the cache, modify
`centaur-tabs-buffer-update-groups` to always rebuild (by advising it). But
this is more invasive.

I recommend **Option A** for correctness, with a note to benchmark performance.

#### 5. Keep the window-deleted cleanup

The existing `window-deletions-functions` handler is correct and should stay.

---

## Implementation Summary

### Architecture Change

| Before | After |
|--------|-------|
| `my/centaur-tabs--reorder-tabset-mru` (advice on `centaur-tabs-line`) **mutated global tabset** → cross-window pollution | **Removed entirely**. No advice on `centaur-tabs-line` |
| `my/tab-buffer-list` returned MRU'd buffers, but centaur-tabs **re-sorted alphabetically** | `my/pw-tab-buffer-list` returns per-window MRU buffers, and the sort is **neutralized** |
| Cache persisted → advice's reorder was last resort | Cache invalidated + no-sort → tabset IS the per-window MRU order |

### What Changed

#### 1. New: `my/pw-tab-buffer-list` (replaces `my/tab-buffer-list`)
- Returns buffers for the **current window's group** in MRU order
- Maintains **per-window state** in `my/centaur-tabs--window-state` hash table
- On first access: initializes from `(buffer-list)` (filtered to current group)
- On subsequent calls: syncs new/killed buffers, moves current buffer to front
- Set as `centaur-tabs-buffer-list-function`

#### 2. New: `my/pw--save-state` helper
- Saves per-window buffer order to the hash table
- Creates new entry if window+group combination doesn't exist yet

#### 3. New: `my/centaur-tabs--buffer-update-groups-no-sort` (advice)
- Uses `cl-letf` to neuter `sort` during `centaur-tabs-buffer-update-groups`
- This prevents the **alphabetical re-sort** that destroyed MRU order

#### 4. Modified: `my/centaur-tabs--force-update`
- Invalidates `centaur-tabs--buffers` cache → forces tabset rebuild on every command
- Logs the resulting tabset with selection status

#### 5. Removed
- `my/centaur-tabs--reorder-tabset-mru` advice on `centaur-tabs-line`
- `my/centaur-tabs--sort-tabset-mru` (unused helper)
- Old stale `advice-remove` lines for extinct advice names

### Debug Messages (17 `[CT-DBG]` points)

All messages use the prefix `[CT-DBG]` for easy grepping. Each message identifies:
- The function (e.g., `pw-tab-buffer-list`, `force-update`, `apply-gradient`)
- The window hash (`sxhash win`)
- The current buffer name
- The buffer order with selection markers (`*` for selected)

To capture logs: `M-x view-echo-area-messages` or check `*Messages*` buffer.

---

## Open Questions for the User

1. **How many windows do you typically use?** Is cross-window interference the
   main issue, or is MRU broken even in a single window?

2. **Performance concerns**: Invalidating the buffer-groups cache on every
   command forces a full rescan of ALL buffers on every redisplay. With
   hundreds of buffers, this could be slow. Do you have many buffers? If so,
   I'll use Option B (smart invalidation — only reset cache when the selected
   window changes).

3. **Current tab order**: When you cycle from tab 1 → tab 2, what order do you
   actually see? Is it completely unchanged (stays [1, 2, 3]) or scrambled?

4. **Are you using frame-based tabs** (the Emacs tab-bar) in addition to
   centaur-tabs? Any other tab-related packages?

5. **Testing**: Can I go ahead and implement the changes in the file for you
   to test?
