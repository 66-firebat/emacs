# eat-new-fix — Optional directory argument for `my/eat-new`

**Target:** `eat-firemacs.el` (section `;; ── Spawn Terminal (M-t) ──`, defun at ~line 81)
**Status:** PROPOSAL — awaiting review, nothing applied
**Date:** 2026-07-17

## Objective

Allow `my/eat-new` to be called as `(my/eat-new "/some/path")`:

- **No argument** → current behavior, spawn shell in `default-directory` (M-t unchanged).
- **Argument given** → a filepath; spawn the shell there instead of `default-directory`.

## Current state

```elisp
(defun my/eat-new ()
  (interactive)
  (let ((index (my/eat-next-available))
        (shell (or explicit-shell-file-name (getenv "ESHELL") shell-file-name))
        (cwd default-directory))          ; ← the only line that decides the cwd
    ...))
```

Callers today: only the `M-t` binding (`keybinds.el:567`), which passes no args —
so adding an `&optional` parameter is backward compatible with zero call-site changes.

The cwd takes effect because `eat-exec` → `make-process` inherits the buffer's
`default-directory`, which we set from `cwd` before calling `eat-exec`.
That mechanism stays; only the *source* of `cwd` changes.

---

## Design decisions (please pick/veto)

### D1. Signature

```elisp
(defun my/eat-new (&optional dir) ...)
```

Plain positional optional. No reason for keyword args or a prefix-arg-numeric
scheme here.

### D2. What counts as a valid DIR — "filepath" semantics

You said *filepath*. Question: what should `(my/eat-new "~/notes/todo.org")` do?

- **Option A (recommended):** coerce file → containing directory.
  If `dir` names a regular file, use `(file-name-directory ...)` of it.
  Makes the API forgiving and matches "spawn a terminal *at* this thing".
- **Option B:** require a directory, `user-error` on files.

Recommendation: **A**. Programmatic callers (e.g. "open terminal at file at
point") then never need their own coercion.

### D3. Nonexistent path handling

- **Option A (recommended): strict** — `(user-error "my/eat-new: no such directory: %s" dir)`.
  Explicit args are contracts; silently ignoring a typo'd path from a
  programmatic caller hides bugs.
- **Option B: silent fallback** to `default-directory`. Matches "preferentially
  use" reading literally, but failures become invisible.
- **Option C: climb to nearest existing parent** (precedent: `grease-toggle`
  does exactly this walk). Nice interactively, surprising programmatically.

Recommendation: **A**. If you later want C for a specific UI flow, wrap it at
the call site, not inside the spawn primitive.

### D4. Normalization

Applied to a provided `dir`, in order:

1. `expand-file-name` — resolves `~`, relative paths (against caller's
   `default-directory`), `..` segments.
2. D2 file→directory coercion.
3. `file-name-as-directory` — ensure trailing slash; Emacs convention for
   `default-directory`, avoids subtle breakage in path-building code.

Note: remote/TRAMP paths need no special handling — `eat-exec` passes
`:file-handler t` to `make-process`, so a `/ssh:host:/path` dir spawns the
shell remotely. Free feature, worth documenting in the docstring.

### D5. Interactive behavior (optional sweetener)

- **Option A (recommended):** keep `(interactive)` — M-t behavior is bit-for-bit
  identical; the new arg is programmatic-only.
- **Option B:** `C-u M-t` prompts:
  ```elisp
  (interactive
   (list (when current-prefix-arg
           (read-directory-name "Spawn eat in: "))))
  ```
  Plain M-t still passes nil. Zero cost to existing muscle memory.

Recommendation: **B** — it's strictly additive, and you get an interactive
escape hatch for "terminal over there" without touching grease/dired.

---

## Proposed implementation (D1 + D2-A + D3-A + D4 + D5-B)

> ⚠ The `` separator in the format strings is U+E0BB (bytes `ee 82 bb`),
> **not** two spaces. As with the previous move, the real edit will be applied
> byte-safely against the live file — do not copy-paste code from this doc.

```elisp
(defun my/eat-new (&optional dir)
  "Spawn a new eat terminal at the lowest available index.
Buffer is named like \"1  19950\" (index +  + PID).

The shell starts in `default-directory', or in DIR when non-nil.
DIR may be a directory or a file (its directory is used) and may be
remote (TRAMP).  Signals `user-error' if DIR does not exist.

Interactively, \\[universal-argument] prompts for DIR."
  (interactive
   (list (when current-prefix-arg
           (read-directory-name "Spawn eat in: "))))
  (let* ((index (my/eat-next-available))
         (shell (or explicit-shell-file-name
                    (getenv "ESHELL")
                    shell-file-name))
         (cwd (if dir
                  (let ((path (expand-file-name dir)))
                    (cond
                     ((file-directory-p path)
                      (file-name-as-directory path))
                     ((file-exists-p path)          ; a file → its directory
                      (file-name-directory path))
                     (t
                      (user-error "my/eat-new: no such directory: %s" dir))))
                default-directory)))
    (let ((buf-name (format "%d  waiting" index)))
      (with-current-buffer (get-buffer-create buf-name)
        (setq default-directory cwd)
        (eat-mode)
        (pop-to-buffer-same-window (current-buffer))
        (unless (and eat-terminal
                     (eat-term-parameter eat-terminal 'eat--process))
          (eat-exec (current-buffer) (buffer-name)
                    "/usr/bin/env" nil
                    (list "sh" "-c" shell)))
        ;; Rename buffer to include the PID
        (when-let* ((proc (eat-term-parameter eat-terminal 'eat--process))
                    ((process-live-p proc)))
          (rename-buffer (format "%d  %d" index (process-id proc))))
        (current-buffer)))))
```

Diff vs. current, conceptually: `let` → `let*`; `cwd` binding grows the
`dir` branch; new `interactive` spec; docstring extended. Body below the
`let*` is untouched.

### Ordering note

`cwd` is validated **before** `my/eat-next-available` reserves nothing and
before any buffer is created — a bad DIR aborts with no side effects
(no stray `"N  waiting"` buffer). That's why validation lives in the `let*`
rather than inside `with-current-buffer`.
(`my/eat-next-available` is pure — scan only — so calling it before the
validation would also be harmless; kept in original order for minimal diff.)

## Future call sites this unlocks (not part of this patch)

- `grease-visit-alt-directory-callback` → `(lambda (dir) (my/eat-new dir))` —
  "open terminal at grease dir" instead of navigating.
- eat-grease: spawn-at-dir as an alternative to the current cd-into-origin
  behavior on quit.
- Dired/embark actions: terminal at file at point via D2 coercion.

## Test checklist (after applying)

1. `M-t` — identical behavior: index naming, cwd = invoking buffer's dir.
2. `C-u M-t` — prompts; spawned shell `pwd` matches choice.
3. `(my/eat-new "~/fire_profile")` — shell starts there; `~` expanded.
4. `(my/eat-new "~/fire_profile/configuration_modules/emacs/init.el")` —
   file coerced to its directory.
5. `(my/eat-new "/nope/nothing")` — clean `user-error`, no buffer created.
6. `(my/eat-new nil)` — same as no-arg.
7. Index recycling still works (kill terminal 1, spawn → reuses 1).
8. Optional: TRAMP dir if you use remote hosts.

## Open questions for your review

1. D2: file→parent coercion OK, or strict directories-only?
2. D3: strict error confirmed, or do you want the grease-style parent climb?
3. D5: adopt the `C-u` prompt, or keep `(interactive)` bare?
