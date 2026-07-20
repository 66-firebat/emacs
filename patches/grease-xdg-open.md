# grease-xdg-open — Open file at point with the system handler

**Target:** `grease/grease.el` (nested git repo; commands section near `grease-visit`, ~line 3050)
**Optional:** `grease/grease-test.el` (207 existing ERT tests; conventions: `grease-test-with-temp-dir` / `grease-test-with-clean-state`)
**Status:** IMPLEMENTED 2026-07-17 — decisions: D1 message on non-file, D2 `user-error`,
D3 `user-error`, D6 evil `<S-return>` binding in grease.el, D7 five tests added
(suite: 212/212 pass), D8 **no git operations** — user commits manually.
**Date:** 2026-07-17

## Objective

New interactive command `grease-xdg-open`:

- Runs `xdg-open` on the **file** under point in a Grease buffer.
- **Files only** — directories are explicitly out of scope.
- The Grease buffer stays open and unchanged (unlike RET, which kills it for files).

Context: this restores a slice of the removed `grease-visit-alt` feature
(whose file-callback default was exactly `xdg-open`), but as a plain,
dependency-free command instead of the callback indirection.

## Relevant plumbing already in grease.el

| Need | Existing helper |
|---|---|
| Entry at point | `grease--get-line-data` → plist `:name :type :entry-kind :id :is-new ...` |
| "Is this a real on-disk entry?" | `grease--line-data-real-file-p` (false for pending creates; **true for dangling symlinks** — see D4) |
| On-disk path despite unsaved rename | registry lookup, same as `grease-visit`: `(or (plist-get (grease--get-file-by-id id) :path) (grease--get-full-path name))` |
| Async launch, no process buffer | `(start-process "grease-xdg-open" nil "xdg-open" path)` — same incantation the old callback used |

Key subtlety carried over from `grease-visit`: if the user renamed a file in
the buffer but hasn't saved, the *displayed* name doesn't exist on disk yet.
We must open the **committed registry path**, not the desired name.

---

## Design decisions (please answer — Q numbers at the bottom)

### D1. Behavior on a directory line

"Should not do anything" taken literally = silent no-op. Options:

- **A (recommended):** `(message "grease-xdg-open: %s is a directory — ignored" name)`
  — no error, no action, but the user learns why nothing happened. Silent
  no-ops on a keypress read as "broken".
- **B:** strictly silent `nil`.
- **C:** `user-error` (rejected — you said "not do anything", an error is doing something loud).

### D2. Behavior when point is not on any entry (header / blank tail line)

- **A (recommended):** `(user-error "Not on a file line")` — matches
  `grease-visit`'s precedent for the same situation.
- **B:** silent.

### D3. Pending (unsaved-create) entries

A line typed into the buffer but not yet saved has no file on disk;
`xdg-open` would fail invisibly (async). Options:

- **A (recommended):** `(user-error "File not saved to disk yet: %s" name)`.
- **B:** run the full commit prompt first (`grease--with-commit-prompt`, like
  RET does) and open after a successful save. Heavier; makes a "preview"
  command capable of writing to disk. Not recommended.

### D4. Existence guard (broken symlinks, externally deleted files)

`grease--line-data-real-file-p` counts a *dangling symlink* as real (by
design). `xdg-open` on it fails asynchronously with zero feedback. Proposal:
after resolving the registry path, require `(file-exists-p path)` — i.e. the
target must resolve — else `user-error`. Cheap and makes failures visible.
Symlink→file entries otherwise work naturally (`:type` is `file`, xdg-open
follows the link).

### D5. Environment guards

- `(executable-find "xdg-open")` → `user-error "xdg-open not found"` instead
  of a cryptic `start-process` failure. Recommended: yes.
- TRAMP: `(file-remote-p path)` → `user-error` — xdg-open on the local host
  cannot open a remote path. Recommended: yes.

### D6. Keybinding

`<S-return>` is free again since the visit-alt removal. Options:

- **A:** bind `<S-return>` → `grease-xdg-open` in the evil block
  (grease.el:3193) — muscle-memory-compatible with the old behavior for files.
- **B:** also/instead a `C-c`-style binding in `grease-mode-map` for non-evil use.
- **C:** ship unbound; bind privately in firemacs `keybinds.el`.
  Keeps the upstream-tracking repo's diff minimal.

No recommendation — depends on whether you intend to PR this upstream (D8).

### D7. Tests (grease-test.el)

Repo convention is ERT + temp-dir macros; visit-alt shipped with 8 tests.
Proposed 5, all mocking `start-process` via `cl-letf` (no real xdg-open spawns):

1. File at point → `start-process` called once with `("xdg-open" <abs path>)`.
2. Directory at point → no `start-process` call, no error (per D1 choice).
3. Point on header → `user-error` (per D2).
4. Pending unsaved entry → `user-error`, no call (per D3).
5. Grease buffer still live and unmodified after opening a file.

### D8. Repo hygiene

`grease/` is a nested repo tracking upstream (PR merges from other authors).
This change = one local commit on your current branch (`grease.el` +
optionally `grease-test.el`). Flagging so it's a decision, not an accident:
upstream-able feature vs. firemacs-local patch.

---

## Proposed implementation (D1-A, D2-A, D3-A, D4+D5 on)

Placement: with the other commands, directly after `grease-refresh`
(~line 3128), before `grease-quit`.

```elisp
(defun grease-xdg-open ()
  "Open the file at point with the system default application.
Uses `xdg-open' asynchronously; the Grease buffer stays open.
Only acts on files: directories are ignored with a message.
Unsaved renames open the file's committed on-disk path; entries that
have never been saved signal an error."
  (interactive)
  (let ((data (grease--get-line-data)))
    (cond
     ((null data)
      (user-error "Not on a file line"))
     ((eq (plist-get data :type) 'dir)
      (message "grease-xdg-open: %s is a directory — ignored"
               (plist-get data :name)))
     ((not (grease--line-data-real-file-p data))
      (user-error "File not saved to disk yet: %s" (plist-get data :name)))
     (t
      (let* ((registry-entry (grease--get-file-by-id (plist-get data :id)))
             (path (or (plist-get registry-entry :path)
                       (grease--get-full-path (plist-get data :name)))))
        (when (file-remote-p path)
          (user-error "Cannot xdg-open a remote file: %s" path))
        (unless (file-exists-p path)
          (user-error "File does not exist on disk: %s" path))
        (unless (executable-find "xdg-open")
          (user-error "Program xdg-open not found in PATH"))
        (start-process "grease-xdg-open" nil "xdg-open" path)
        (message "Opened: %s" (file-name-nondirectory path)))))))
```

Notes:
- No commit prompt, no buffer mutation, no state cleared — pure read + spawn.
- Process name `"grease-xdg-open"` (not `"xdg-open"`) so `list-processes`
  attributes it.
- Guard order: cheap plist checks → remote → existence → executable → spawn.

## Test checklist (manual, after applying)

1. Point on a saved file → opens in system app; grease buffer untouched.
2. Point on a directory → message, nothing else.
3. Point on header line / trailing blank line → `user-error`.
4. Type a new filename (unsaved), point on it → `user-error`.
5. Rename a file in-buffer w/o saving, point on it → *old* on-disk file opens.
6. Symlink → file: target app opens. Broken symlink → clean `user-error`.
7. If bound (D6): `S-RET` triggers it in evil normal state.

---

## Open questions

- **Q1 (D1):** Directory at point — message (A) or strictly silent (B)?
- **Q2 (D2):** Header/blank line — `user-error` (A) or silent (B)?
- **Q3 (D3):** Unsaved entries — error (A) confirmed?
- **Q4 (D6):** Keybinding: `S-RET` in grease.el, `grease-mode-map` too, or
  keep it in your private keybinds.el only?
- **Q5 (D7):** Add the 5 ERT tests to grease-test.el?
- **Q6 (D8):** Is a local commit on the nested grease repo OK (vs. keeping it
  as a firemacs-side patch), i.e. do you plan to upstream this?
