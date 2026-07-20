# PATCH — Grease Plugin Loader Fixes

## Review feedback

> Load plugins only after Grease has provided itself. Probably best to either
> remove the shipped test-plugin.el or hide it under some debug or dev
> variable, and also filter discovered entries with file-regular-p so
> directories ending in .el are ignored. Briefly document that this is a
> lightweight plugin loader and how users should configure a persistent
> plugin directory.

---

## Fix 1: Load plugins AFTER `(provide 'grease)`

### The problem

Current code at the bottom of `grease.el` (lines 3597–3600):

```elisp
;; Load user plugins when enabled (see `grease-load-plugins').
(when grease-load-plugins
  (grease--apply-plugin-config))

(provide 'grease)
```

Plugins are loaded **before** `(provide 'grease)` runs. This breaks plugins that:

- Call `(require 'grease)` — Emacs sees `grease.el` is being loaded and returns,
  but `(featurep 'grease)` is still nil afterward.
- Use `(with-eval-after-load 'grease ...)` — the callback is queued but doesn't
  fire until `(provide 'grease)` runs. If the plugin relies on `grease` symbols
  *during its own load*, those symbols may not be available yet.

### Why this happens

Emacs's `require`/`provide` system tracks features via the `features` list. A
feature is only "provided" when `(provide 'grease)` executes. Before that point:

```
(featurep 'grease)  →  nil       ;; even though grease.el is mid-load
```

So plugins loading during this window see an incomplete picture.

### The fix (two parts)

#### Part A: Move `(provide 'grease)` above the plugin-loading call

```elisp
(provide 'grease)

;; Load user plugins when enabled (see `grease-load-plugins').
(when grease-load-plugins
  (grease--apply-plugin-config))

;;; grease.el ends here
```

This is a one-line move. `(provide)` is just a function — execution continues
after it. Now when `grease--apply-plugin-config` loads each `.el` file:

- `(featurep 'grease)` → `t` — the feature is fully registered.
- `(require 'grease)` → returns `grease` without re-loading.
- Any `(with-eval-after-load 'grease ...)` body runs immediately (feature already
  provided).
- All grease functions, variables, and macros are available.

**The change in `grease.el`:**

```diff
-  ;; Load user plugins when enabled (see `grease-load-plugins').
-  (when grease-load-plugins
-    (grease--apply-plugin-config))
-
   (provide 'grease)
+
+  ;; Load user plugins when enabled (see `grease-load-plugins').
+  (when grease-load-plugins
+    (grease--apply-plugin-config))
```

#### Part B: Add a `(featurep 'grease)` guard inside the loader function

Moving the call site is a good fix, but `grease--apply-plugin-config` is a
named function — someone could call it interactively or from another code path
when grease.el is not loaded. Without a guard, plugins would execute without
their host package available.

Current `grease--apply-plugin-config` body:

```elisp
(defun grease--apply-plugin-config (&optional force)
  "..."
  (when (or force (not grease--plugins-loaded))    ;; ← only checks "already loaded?"
    (setq grease--plugins-loaded t)
    (let ((loaded 0) (failed 0))
      (dolist (file (grease--plugin-files))
        ...))))
```

New — add a `(featurep 'grease)` check before proceeding:

```elisp
(defun grease--apply-plugin-config (&optional force)
  "..."
  (unless (featurep 'grease)
    (error "Cannot load Grease plugins: Grease itself is not loaded"))
  (when (or force (not grease--plugins-loaded))
    (setq grease--plugins-loaded t)
    (let ((loaded 0) (failed 0))
      (dolist (file (grease--plugin-files))
        ...))))
```

Why `error` and not `user-error`? Because this function is not meant to be
called interactively by end users — it runs automatically from init code. If it
fires without `grease` in `features`, it's a bug, not a user mistake. The error
surfaces immediately so the problem is obvious.

---

## Fix 2: Remove `test-plugin.el` from shipped plugins (or gate it)

### The problem

The file `plugins/test-plugin.el` exists in the repository:

```
grease/
└── plugins/
    └── test-plugin.el    ← developers don't want this loaded on user machines
```

When `grease-load-plugins` is non-nil, `grease--apply-plugin-config` scans all
`*.el` files in `plugins/` and loads them indiscriminately. This means the test
plugin runs on every user's machine who enables plugin loading.

### The fix

**Option A: Delete the file** (simplest)

Remove `plugins/test-plugin.el` from the repo. Tests should live in
`grease-test.el` or under `tests/`. A shipped plugin directory should only
contain plugins meant for end users.

**Option B: Gate it behind a dev variable** (if needed for development)

```elisp
(defvar grease-load-test-plugins nil
  "When non-nil, also load `test-plugin.el' from `grease-plugins-directory'.
Only enable this during development.  Ignored when `grease-load-plugins'
is nil.")

(defun grease--plugin-files ()
  "Return top-level plugin files in `grease-plugins-directory', sorted.
Dot-prefixed files are excluded, including Emacs lockfiles (.#foo.el).
Files starting with \"test-\" are excluded unless
`grease-load-test-plugins' is non-nil."
  (let ((dir (expand-file-name grease-plugins-directory
                               grease--source-directory)))
    (when (file-directory-p dir)
      (let ((files (directory-files dir t "\\`[^.#].*\\.el\\'")))
        (if grease-load-test-plugins
            files
          (cl-remove-if (lambda (f)
                          (string-prefix-p "test-" (file-name-nondirectory f)))
                        files))))))
```

**Recommendation: Option A** (delete it). A test plugin has no business shipping
to end users.

---

## Fix 3: Filter with `file-regular-p` to skip directories

### The problem

`directory-files` returns all entries matching the regex — including
subdirectories whose names happen to end in `.el`. For example:

```
plugins/
├── eat.el              ← a real plugin file
├── my-bundle.el/       ← a SUBDIRECTORY ending in .el!
│   └── ...
└── utils.el/           ← another subdirectory
```

The current `grease--plugin-files` does:

```elisp
(directory-files dir t "\\`[^.#].*\\.el\\'")
```

This returns `my-bundle.el/` and `utils.el/` as results. Then `(load
"plugins/my-bundle.el" nil 'nomessage)` — which tries to load a directory as if
it were a file. On most systems this produces a confusing error, or `load`
silently loads `my-bundle.el/my-bundle.el` if it exists.

### The fix

Add a `file-regular-p` filter:

```elisp
(defun grease--plugin-files ()
  "Return top-level plugin files in `grease-plugins-directory', sorted.
Dot-prefixed files are excluded, including Emacs lockfiles (.#foo.el).
Directories ending in \".el\" are also excluded (only regular files)."
  (let ((dir (expand-file-name grease-plugins-directory
                               grease--source-directory)))
    (when (file-directory-p dir)
      (seq-filter
       #'file-regular-p
       (directory-files dir t "\\`[^.#].*\\.el\\'")))))
```

The `seq-filter #'file-regular-p` wrapper drops any entry that isn't a plain
file — symlinks to regular files pass (they resolve), but directories and
symlinks to directories do not.

Note: this adds an implicit dependency on `seq` (built-in since Emacs 25.1).
Alternative without `seq` if needed:

```elisp
(cl-remove-if-not #'file-regular-p
                  (directory-files dir t "\\`[^.#].*\\.el\\'"))
```

This uses `cl-lib` which Grease already requires.

---

## Fix 4: Document the plugin loader and persistent directory config

### What to add to `README.org`

A new section after Installation, before Configuration:

```org
** Plugin Loader

Grease includes a lightweight plugin system. Place =.el= files in the
=plugins/= directory adjacent to =grease.el=, and enable auto-loading:

#+begin_src emacs-lisp
(setq grease-load-plugins t)  ;; set BEFORE loading grease.el
(require 'grease)
#+end_src

Every =.el= file in the directory (except dotfiles and =test-= prefixed
files) is loaded with =load=, isolated via =condition-case= — a failing
plugin is reported with =display-warning= and does not block the others.

*** Custom plugin directory

Override the default =plugins/= directory:

#+begin_src emacs-lisp
(setq grease-plugins-directory "~/.emacs.d/grease-plugins/")
(setq grease-load-plugins t)
#+end_src

A relative path is resolved against =grease.el='s location. Set both
variables /before/ loading Grease.

*** Writing a plugin

Plugins are ordinary Emacs Lisp files. The recommended skeleton:

#+begin_src emacs-lisp
;;; my-grease-plugin.el --- Description  -*- lexical-binding: t; -*-

;;; Commentary:
;; ...

;;; Code:

(defun my-grease-plugin--do-something ()
  "React to a Grease event."
  ...)

;; Register with Grease hooks.  Because plugins load /after/
;; (provide 'grease), all Grease functions and variables are available.
(add-hook 'grease-visit-hook #'my-grease-plugin--do-something)

(provide 'my-grease-plugin)
;;; my-grease-plugin.el ends here
#+end_src

Plugins can use =add-hook= on any Grease hook, =advice-add= on Grease
functions, or read buffer-local Grease variables like =grease--root-dir=.
```

### What to add to `grease.el` docstrings

Update the docstring of `grease--apply-plugin-config`:

```elisp
(defun grease--apply-plugin-config (&optional force)
  "Load every plugin file from `grease-plugins-directory'.

Plugins are ordinary Emacs Lisp files loaded with `load'.  Each file
is isolated with `condition-case'; a failing plugin is reported via
`display-warning' and does not prevent the remaining plugins from
loading.

This function runs only once per session, after `(provide 'grease)'
has executed, so plugins have full access to all Grease symbols.
Call with FORCE non-nil to reload all plugins (e.g. after
development changes).

Only regular files matching `*.el' are loaded.  Dot-prefixed files,
Emacs lockfiles (.#foo.el), subdirectories, and files prefixed with
\"test-\" are silently skipped."
  ...)
```

And update `grease-load-plugins`:

```elisp
(defcustom grease-load-plugins nil
  "When non-nil, load every plugin from `grease-plugins-directory'.
Plugins are ordinary Emacs Lisp files loaded with `load' when Grease
finishes loading itself.  This executes arbitrary code; enable it
only for plugin directories you trust.

Plugins are loaded /after/ (provide 'grease), so all Grease functions,
hooks, and variables are available to plugin code.

Set this before loading `grease.el', or set it and call
\(grease--apply-plugin-config) manually."
  :type 'boolean
  :group 'grease)
```

---

## Summary of changes to `grease.el`

| Line(s) | Change |
|---------|--------|
| Bottom of file | Move `(provide 'grease)` above the `(when grease-load-plugins ...)` block |
| `grease--apply-plugin-config` | Add `(unless (featurep 'grease) (error ...))` guard at top of function |
| `grease--plugin-files` | Add `file-regular-p` filter to the `directory-files` result |
| `grease--plugin-files` | Add `test-` prefix exclusion (or delete test-plugin.el) |
| Docstrings | Update `grease-load-plugins` and `grease--apply-plugin-config` to describe the loader |

## Summary of other changes

| File | Change |
|------|--------|
| `plugins/test-plugin.el` | Delete |
| `README.org` | Add "Plugin Loader" section with usage, custom directory, and plugin skeleton |
