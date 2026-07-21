# eaterz-kill-grease — Kill grease buffer when spawning eat from it

**Target:** `eat/eaterz.el` — `my/eat-new-from-grease` handler
**Status:** APPROVED — ready for implementation
**Date:** 2026-07-21

---

## Objective

When `M-t` spawns an eat terminal from a grease buffer, prompt about
unsaved changes, then kill the grease buffer afterward to prevent
buffer clutter.

---

## Current state

```elisp
(defun my/eat-new-from-grease ()
  "Spawn eat in the root directory of the current grease buffer."
  (if (featurep 'grease)
      (my/eat-new grease--root-dir)
    (display-warning ...)
    (my/eat-new)))
```

`my/eat-new` calls `pop-to-buffer-same-window`, so the eat buffer replaces
the grease buffer in the window.  But the grease buffer stays alive (just
buried), leaving a zombie buffer behind.

---

## Grease state audit

Grease has **no existing mechanism** to check for unsaved changes when
moving away from a buffer.  `grease-close-window` just calls
`delete-window` with no prompt.

Two buffer-local variables track state:

| Variable | Meaning |
|----------|---------|
| `grease--buffer-dirty-p` | Non-nil when the buffer has unsaved edits |
| `grease--pending-changes` | Pending (staged) changes across directory visits |

Both must be checked: `(or grease--buffer-dirty-p grease--pending-changes)`.

**Decision:** if dirty, prompt → `grease-save` → kill.

---

## Design options

### Option A — Prompt first, spawn, then kill

```
1. Check grease--buffer-dirty-p
2. If dirty → y-or-n-p prompt
3. If user says no → abort (user-error)
4. Record grease buffer reference
5. Spawn eat via (my/eat-new grease--root-dir)
6. Kill the original grease buffer
```

**Pros:** User can abort before eat buffer is created (no wasted index).
**Cons:** The prompt happens *before* any visual change, which might be
disorienting — user presses M-t, sees a prompt, then a terminal appears.

### Option B — Spawn first, prompt, then kill

```
1. Record grease buffer reference + dirty-p status
2. Spawn eat via (my/eat-new grease--root-dir)
3. After eat is live, check dirty-p
4. If dirty → y-or-n-p prompt in the eat buffer's context
5. Kill the original grease buffer
```

**Pros:** Visual flow is smoother — eat terminal appears immediately.
**Cons:** Harder to abort (eat buffer already exists).  Prompting from
inside an eat buffer (semi-char mode) may be awkward.

### Option C — Spawn, kill unconditionally, prompt only for dirty

```
1. Record grease buffer reference + dirty-p status
2. Spawn eat via (my/eat-new grease--root-dir)
3. If dirty → y-or-n-p: "Grease has unsaved changes. Save before closing?"
   - Yes → grease-save, then kill
   - No → kill without saving
4. If clean → kill silently
```

**Pros:** Cleanest user experience.  Eat appears, user decides fate of
grease buffer.
**Cons:** If user says "no" to saving, changes are lost.  Some users
might expect changes to persist in the buried buffer.

---

## Recommendation: Option C

~~The mental model is: "I'm done with this grease buffer, open a terminal
here instead."  The grease buffer is ephemeral — the user navigated there
to find a directory, and now wants to work in it.  Prompting about unsaved
changes is a safety net, not a workflow gate.~~

**Overridden by Q1 decision: Option A** — prompt first via
`grease-save-all-buffers`, which handles its own prompt/abort flow.

---

## Implementation sketch (Option A)

```elisp
(defcustom my/eat-kill-grease-on-spawn t
  "When non-nil, kill the grease buffer after spawning an eat terminal from it.
If nil, the grease buffer is left alive (buried behind the eat buffer)."
  :type 'boolean
  :group 'eat)

(defun my/eat-new-from-grease ()
  "Spawn eat in the root directory of the current grease buffer.
Saves any pending grease changes via `grease-save-all-buffers',
which handles its own prompts.  If the user cancels the save,
`user-error' is signaled and no eat buffer is created.
If `my/eat-kill-grease-on-spawn' is non-nil, the grease buffer
is killed after spawning to prevent clutter."
  (if (featurep 'grease)
      (let ((grease-buf (current-buffer)))
        ;; Save handles its own prompt/abort flow
        (when (fboundp 'grease-save-all-buffers)
          (with-current-buffer grease-buf
            (grease-save-all-buffers)))
        ;; Spawn eat in the grease root directory
        (my/eat-new grease--root-dir)
        ;; Kill the grease buffer if configured
        (when (and my/eat-kill-grease-on-spawn
                   (buffer-live-p grease-buf))
          (kill-buffer grease-buf)))
    (display-warning
     'eat
     (concat "grease-mode detected but grease.el is not loaded; "
             "spawning in default-directory")
     :warning)
    (my/eat-new)))
```

---

## Questions

### Q1. Which option — A, B, or C?  ✅

**Decision: A** — prompt first, abort possible, then spawn + kill.
The user can cancel before an eat buffer is created (no wasted index).

### Q2. Prompt wording for dirty grease buffer

~~Not needed — `grease-save-all-buffers` handles its own prompt/abort flow.~~

### Q3. What to do when user says "no" to the dirty prompt?

~~Not needed — `grease-save-all-buffers` signals `user-error` on cancel, so
`my/eat-new-from-grease` never reaches the spawn/kill code.~~

### Q4. Auto-save or manual save?

~~Not needed — `grease-save-all-buffers` is the save mechanism.~~

### Q5. Clean buffer — silent kill or confirm?  ✅

**Decision: kill silently.**  The save step already handled any interaction.
The kill is just cleanup.

### Q6. Should this behavior be a `defcustom` toggle?  ✅

**Decision: `defcustom`** — `my/eat-kill-grease-on-spawn`, default `t`.
Users can set to nil to keep the grease buffer alive after spawning eat.
