# grease-plugins — Opt-in plugin loader for Grease

**Target:** `grease/grease.el` (nested repo — **no git operations by me**, you commit)
**Related:** `grease/plugins/test-plugin.el` (untracked manual fixture, stays out of tests per Q10)
**Status:** IMPLEMENTED 2026-07-18 — all FQs resolved (see bottom); suite 218/218;
e2e verified with plugins/test-plugin.el; **no git operations** — user commits
**Date:** 2026-07-17

## Objective

Opt-in mechanism loading external `.el` plugin files from a directory
adjacent to grease.el. Single public switch, private worker.

## Resolved decisions (your answers)

| # | Decision |
|---|---|
| Q1 | One public defcustom `grease-load-plugins`; private worker named **`grease--apply-plugin-config`** |
| Q2 | Plugins load **at grease.el load time** (guarded footer) |
| Q3 | **Per-file `condition-case` isolation**; failures warn, never abort the rest or grease itself |
| Q4 | **All top-level `.el` files** — no recursion into subdirectories |
| Q5 | Reload = plain re-`load` (redefinition wins), no unload machinery; automatic load once per session via guard; interactive reload bypasses guard |
| Q6 | `grease-plugins-directory` defcustom; **default = `plugins/` adjacent to grease.el**, computed from grease.el's own location at load time |
| Q7 | **No** `grease-plugins-loaded-hook` |
| Q8 | Success message goes to the **\*Messages\* buffer** via `message`; silent when directory missing/empty |
| Q9 | **Yes** — ERT tests (temp-dir fixtures), full suite run after |
| Q10 | `plugins/test-plugin.el` stays **untracked**, manual testing later |

---

## Final design

### Self-location (grease.el finds itself)

```elisp
(defconst grease--source-directory
  (file-name-directory
   (or load-file-name buffer-file-name (locate-library "grease") ""))
  "Directory containing grease.el, captured at load time.")

(defun grease--default-plugins-directory ()
  "Return the default plugins directory: plugins/ adjacent to grease.el."
  (expand-file-name "plugins" grease--source-directory))
```

`load-file-name` covers normal `load`/`my/load-module`; `buffer-file-name`
covers `M-x eval-buffer` during development; `locate-library` is the
last-resort fallback.

### Public surface (the only two knobs)

```elisp
(defcustom grease-load-plugins nil
  "When non-nil, load every plugin from `grease-plugins-directory'.
Plugins are ordinary Emacs Lisp files loaded with `load' when grease.el
itself is loaded.  This executes arbitrary code; enable it only for
plugin directories you trust.

Like `grease-show-hidden', set this before grease.el is loaded."
  :type 'boolean
  :group 'grease)

(defcustom grease-plugins-directory (grease--default-plugins-directory)
  "Directory searched for Grease plugin files (*.el).
A relative value is resolved against grease.el's own directory."
  :type 'directory
  :group 'grease)
```

### Private worker (no public command — FQ1)

```elisp
(defvar grease--plugins-loaded nil
  "Non-nil once plugins have been loaded in this session.")

(defun grease--plugin-files ()
  "Return top-level plugin files in `grease-plugins-directory', sorted.
Excludes dot-prefixed files, including Emacs lockfiles (.#foo.el).
Backup files (foo.el~) never match the .el suffix and are excluded
naturally."
  (let ((dir (expand-file-name grease-plugins-directory
                               grease--source-directory)))
    (when (file-directory-p dir)
      (directory-files dir t "\\`[^.#].*\\.el\\'"))))

(defun grease--apply-plugin-config (&optional force)
  "Load every plugin file from `grease-plugins-directory'.
Each file is isolated with `condition-case'; a failing plugin is
reported via `display-warning' and does not prevent the remaining
plugins from loading.  Loads once per session unless FORCE is non-nil."
  (when (or force (not grease--plugins-loaded))
    (setq grease--plugins-loaded t)
    (let ((loaded 0) (failed 0))
      (dolist (file (grease--plugin-files))
        (condition-case err
            (progn
              (load file nil 'nomessage)
              (cl-incf loaded))
          (error
           (cl-incf failed)
           (display-warning
            'grease
            (format "Plugin %s failed to load: %s"
                    (file-name-nondirectory file)
                    (error-message-string err))
            :error))))
      (when (or (> loaded 0) (> failed 0))
        (message "Grease: loaded %d plugin%s%s"
                 loaded (if (= loaded 1) "" "s")
                 (if (> failed 0) (format " (%d failed)" failed) ""))))))
```

### Load-time footer

```elisp
;; Bottom of grease.el, immediately before (provide 'grease):
(when grease-load-plugins
  (grease--apply-plugin-config))
```

### Behavior matrix

| Situation | Result |
|---|---|
| `grease-load-plugins` nil (default) | Nothing happens, ever |
| t before grease.el loads | Plugins load during grease.el load; count → \*Messages\* |
| Directory missing or no matching files | Silent no-op (`grease--plugins-loaded` still set) |
| One plugin signals an error | `display-warning` names file + error; remaining plugins load; message reports "(N failed)" |
| grease.el reloaded in-session | Guard prevents double-load (footer honors guard) |
| `(setq grease-load-plugins t)` mid-session | No effect until grease.el is loaded again (FQ4: accepted); power users can eval `(grease--apply-plugin-config t)` |

### Placement in grease.el

- Constants/defcustoms/worker: new `;;;; Plugin Loading` section after the
  faces/config area (near the other defcustoms, before `;;;; Global State`).
- Footer: bottom of file, before `(provide 'grease)`.

## Tests (Q9 — grease-test.el, temp fixtures only)

Fixture pattern: temp dir as `grease-plugins-directory` (let-bound), plugin
files written with `write-region`, each appending its name to a
`grease-test--plugin-log` list so load *and order* are observable.
`grease--plugins-loaded` let-bound to nil per test.

1. **Loads all top-level .el alphabetically** — log equals sorted names.
2. **Ignores non-plugins** — `notes.txt`, `.#lock.el`, `.hidden.el`,
   `sub/inner.el` all untouched.
3. **Error isolation** — `a-broken.el` = `(error "boom")`, `b-good.el`
   loads anyway; `display-warning` captured via `cl-letf` and names the file.
4. **Once-per-session guard** — second `grease--apply-plugin-config` call
   loads nothing; `(grease--apply-plugin-config t)` loads again.
5. **Missing directory** — nonexistent `grease-plugins-directory`: no error,
   no log entries.
6. **Relative directory** — resolves against `grease--source-directory`
   (FQ3), never against `default-directory`.

Result: 6/6 new tests pass; full suite 218/218 (was 212).

## Manual checklist (after implementation — your `test-plugin.el` moment)

1. Default: no plugin message at startup.
2. `(setq grease-load-plugins t)` added in init.el **above** the
   `(my/load-module "grease/grease.el")` line → restart →
   `[grease plugin] test-plugin.el loaded!` + `Grease: loaded 1 plugin`.
3. Broken plugin dropped into plugins/ → warning in \*Warnings\*, Emacs
   still starts, grease still works.
4. To re-run plugins mid-session (no public command per FQ1):
   `M-: (grease--apply-plugin-config t)`.

---

## Follow-up questions — RESOLVED

- **FQ1:** No public reload command — `grease-reload-plugins` dropped;
  `grease--apply-plugin-config` is the only loader (FORCE arg for tests and
  manual eval).
- **FQ2:** Dot-prefixed files excluded (lockfiles `.#foo.el`, hidden
  `.foo.el`); `foo.el~` excluded naturally by suffix.
- **FQ3:** Relative `grease-plugins-directory` values ALWAYS resolve against
  grease.el's directory (`grease--source-directory`).
- **FQ4:** Load-time-only trigger accepted; no `:set` magic on the defcustom.
