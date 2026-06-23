# 🔥 Emacs Configuration — Firebat Edition

A clean, terminal-first Emacs config with **Evil** (Vim emulation), **Eat** terminal, **Doom Modeline**, **Centaur Tabs**, and **Pi** AI coding agent. Designed for the `firebat` theme (`#2b2b2b` background, `#ff4400` accent).

**Author:** `fireshark`
**Launch:** `emacs -nw`

---

## ⚠️ TODO — Known Issues & Missing Features

- [ ] **Comment toggling** — No keybinding exists for `comment-dwim` / `comment-line`. Needs a binding like `SPC ;` or `gc` (Evil standard). See [Issue: No Comment Keybinding](#).
- [ ] **Duplicated `eat.el` load** — `init.el` loads `eat.el` twice (sections 13b and 13i). The second load is a no-op but should be cleaned up.
- [ ] **`SPC d` prefix collision** — `SPC d d` is `my/dired-from-eat` and `SPC d f` / `SPC d v` / etc. are help/docs. This means `SPC d f` and friends are ambiguous; Dired-related bindings under `SPC d` conflict with help bindings under the same prefix. Consider moving dired to `SPC d` and docs to `SPC h`, or vice versa.
- [ ] **Stale `dirvish` reference in old README** — Dirvish was removed; the config now uses plain Dired with `my/dired-from-eat`.
- [ ] **`wl-clipboard.el` Wayland-only** — No graceful fallback for X11/macOS. The clipboard integration silently does nothing on non-Wayland sessions.
- [ ] **No `rainbow-delimiters` package actually installed** — The theme defines faces for it, but `rainbow-delimiters` is not listed in `init.el` via `use-package`. Faces are dead code.
- [ ] **`SPC SPC` is `consult-buffer`** — This overrides the common "M-x / execute-command" expectation on double-SPC. Consider `SPC SPC` → `M-x` or document the choice.
- [ ] **No `project` `consult-project` source** — `consult-buffer` could include project buffers as a source.
- [ ] **No file-explorer tree (neotree/treemacs)** — Dired is the only file navigation. Consider adding `treemacs` or `neotree` for sidebar browsing.

---

## Table of Contents

1. [Packages & Dependencies](#packages--dependencies)
2. [File-by-File Reference](#file-by-file-reference)
3. [Complete Keybinding Table](#complete-keybinding-table)
4. [Theme Reference](#theme-reference)
5. [Quick Start](#quick-start)

---

## Packages & Dependencies

### Core (autoloaded or demand-loaded)

| Package | Role | Load Strategy |
|---|---|---|
| **evil** | Vim emulation core | `:demand t` |
| **evil-collection** | Vim keybindings for every mode | `:demand t`, after evil |
| **general** | Leader key definer (SPC / C-SPC) | `:demand t` |
| **vertico** | Vertical minibuffer completion | `:demand t` |
| **marginalia** | Completion candidate annotations | `:demand t` |
| **consult** | Powerful search & navigation (consult-line, consult-grep, etc.) | `:demand t` |
| **which-key** | Show available keybindings on prefix keys | `:demand t` |
| **doom-modeline** | Informative mode line with Nerd Font icons | `:demand t` |
| **nerd-icons** | Nerd Font icon provider | `:commands nerd-icons-install-fonts` |
| **centaur-tabs** | Aesthetic tab bar at top of frame | `:demand t` |
| **eat** | Terminal emulator (replaces vterm) | Configured via custom `eat.el` |

### Deferred (loaded on demand)

| Package | Role | Trigger |
|---|---|---|
| **magit** | Git porcelain | `:defer t` |
| **diff-hl** | Uncommitted change indicators | Hook + global mode |
| **eglot** | LSP client (built-in Emacs 29+) | `:defer t` |
| **org** | Notes, TODOs, Agenda | `:defer t` |
| **avy** | Visual character jump | `:defer t` |
| **project** | Project management (built-in) | `:defer t` |
| **julia-mode** | Julia language support | `:defer t`, auto via `.jl` |
| **python** | Python language support (built-in) | `:defer t`, auto via `.py` |
| **treesit** | Tree-sitter syntax highlighting (built-in Emacs 30) | `:demand t`, `:ensure nil` |
| **pi-coding-agent** | Pi AI coding agent frontend | `:defer t` |

### Custom Modules (local `.el` files)

| File | Role |
|---|---|
| `theme.el` | Firebat custom theme definition |
| `statuscolumn.el` | Visual line numbers with `┃`/`┣` separators |
| `doom-modeline.el` | Custom modeline segments (percentage glyph, buffer-info) |
| `centaur-tabs.el` | Tab bar with group labels, git branch info, custom labels |
| `diff-hl.el` | Change indicator icons in left margin |
| `eat.el` | Terminal emulator with statuscolumn-aware width calculation |
| `consult-buffer.el` | Custom consult-buffer source (Eat terminal spawning) |
| `keybinds.el` | ALL custom keybindings (leader, normal mode, Pi buffers) |
| `panes.el` | Window divider glyph (`┼` instead of `\|`) |
| `pi.el` | Pi coding agent integration, vertical split layout |
| `wl-clipboard.el` | Wayland clipboard bridge (wl-copy / wl-paste) |

### Optional External Dependencies

- **Nerd Font** (e.g., `Symbols Nerd Font Mono`) — required for mode-line, diff-hl, and centaur-tabs icons
- **Julia LanguageServer.jl** — for LSP in Julia buffers: `using Pkg; Pkg.add("LanguageServer")`
- **Pi CLI** — for AI coding agent: `npm install -g @earendil-works/pi-coding-agent`
- **wl-clipboard** (system package) — for Wayland clipboard in terminal: `wl-copy` + `wl-paste`

---

## File-by-File Reference

### `init.el` — Bootstrap & Orchestration

The entry point. Sets up:

1. **Package management** — MELPA repository, `use-package` with `:ensure t`
2. **Sane defaults** — Disables GUI bars, `show-paren-mode`, `global-auto-revert-mode`, `save-place-mode`, `recentf-mode`, trailing whitespace cleanup on save, dedicated backup/auto-save dirs, symlink following, bell silencing
3. **Evil + evil-collection** — Vim emulation everywhere
4. **general** — SPC leader key (actual bindings in `keybinds.el`)
5. **which-key** — Available binding popup after 0.5s
6. **Custom file loading** — Each `.el` file loaded via `(load (expand-file-name "file.el" real-dir))` relative to config directory
7. **Language support** — Julia & Python with Eglot (LSP) and Tree-sitter (syntax highlighting)
8. **Org mode** — Capture templates, TODO keywords, agenda setup
9. **Avy** — Visual character jumping
10. **Pi coding agent** — AI-assisted coding
11. **wl-clipboard** — Wayland clipboard integration
12. **Firebat theme** — Load and enable

Key settings:
- `evil-want-keybinding nil` — delegates keybinding setup to evil-collection
- `evil-undo-system 'undo-redo` — modern undo-redo (Emacs 28+)
- `gc-cons-threshold` — 100MB during startup, 800KB after
- `eglot-autoshutdown t` — kill LSP server when last buffer closes
- `delete-trailing-whitespace` — on `before-save-hook`

### `theme.el` — Firebat Theme

Full custom `deftheme` with a 7-stop gradient palette:

```
#ff4400  →  #da4007  →  #bf3d0c  →  #913716  →  #603120  →  #462e25  →  #2b2b2b
(accent)                                              (selection)    (bg)
```

Faces defined for: Core UI, syntax highlighting, mode-line, Evil search, Vertico/Corfu, Consult, Magit, Org, Doom Modeline, Eat terminal ANSI, Statuscolumn, Diff-hl, Centaur Tabs, Which-key, Avy, Flymake/Eglot diagnostics, Rainbow Delimiters, Dired.

### `keybinds.el` — All Custom Keybindings

The single source of truth for every non-trivial keybinding. Uses the `leader` definer from `general.el`:

- **Normal/Visual/Motion states:** `SPC` is the prefix
- **Insert/Emacs states:** `C-SPC` is the prefix (so SPC still inserts a space)

Also defines normal-mode overrides for tab navigation, buffer switching, line motion, and Avy jumping, plus Pi buffer keybindings.

**Utility functions defined:**
- `my/eat-new` — spawn Eat terminal at lowest available index
- `my/switch-to-other-buffer` — toggle A ↔ B buffers
- `my/buffer-goto` — jump to buffer by index number (interactive completing-read)
- `my/eat-goto` — jump to/spawn Eat terminal by index
- `my/dired-from-eat` — open Dired in the Eat terminal's current working directory
- `my/eat-spawn-at-index` — spawn Eat at a specific index
- `my/filtered-buffer-list` — buffer list excluding `*scratch*` and `*Messages*`

### `statuscolumn.el` — Permanent Avy Jump Labels

Every visible line shows an avy-style jump label in the statuscolumn.
The current line displays the absolute line number instead:

- Non-current lines: `LABEL ┃`
- Current line:       `LINENUMBER ┣`

Pressing `;` types the label to jump — no temporary overlays. Terminal
buffers (eat/vterm) are excluded for performance.

### `doom-modeline.el` — Custom Modeline Segments

- **Custom percentage** — 8-level Nerd Font scrollbar glyph (󰰗 → 󰪥) instead of numeric percentage
- **Custom buffer-info** — buffer name + state icon (modified/read-only), no mode icon
- **Modeline layout** — Left: `eldoc bar window-state workspace-name window-number modals matches follow <percent> <buffer-info> remote-host`; Right: `compilation misc-info project-name ... check time`

### `centaur-tabs.el` — Tab Bar with Group Labels

- **Group name segment** — prepended to tab bar, shows ` branch:hash` for project groups, or icon + name for others ( Elisp,  Magit,  Shell,  Dired,  Org)
- **Custom tab labels** — Active: `█ filename `, Inactive: ` filename `; modified files get `󱍸` prefix
- **Git branch cache** — branch:hash cached per project, invalidated on buffer switch
- **Style** — "bar" style, underline active bar, height 24

### `eat.el` — Terminal Emulator

- **Shell integration** — OSC 7 directory tracking (updates `default-directory` on `cd`)
- **Statuscolumn-aware** — custom `window-adjust-process-window-size-function` subtracts 2 characters for the `┃` separator
- **Input mode** — `semi-char` (mix of Emacs and char-mode input)
- Replaces the vterm configuration from earlier versions

### `diff-hl.el` — Change Indicators

Nerd Font icons in the left margin:

| Change | Icon |
|---|---|
| Insertion | ` ` |
| Deletion | ` ` |
| Modification | ` 󱍸` |
| Unknown | ` ┆` |
| Ignored | ` i` |

Features: global mode in all file buffers, Dired integration, `flydiff` for live-updating, Magit post-refresh hook.

### `consult-buffer.el` — Custom Buffers

Adds an **Eat terminal source** to `consult-buffer` (which is bound to both `C-b` and `SPC SPC`):

- Existing Eat buffers appear as completions
- Typing a number spawns a new Eat at that index (e.g., typing `5` → Eat index 5)
- Marked `:default t` and prepended so it's checked first

### `panes.el` — Window Dividers

- Replaces vertical border `|` with `┼` (U+253C) via display table
- Also pushes the wrap glyph (continuation line) to `·` (U+00B7) in `shadow` face
- Hooks into `eat-mode-hook` to re-apply in terminal buffers (which have their own display tables)

### `pi.el` — Pi AI Coding Agent

- **Convenience alias** — `M-x pi` starts/focuses Pi
- **Vertical split layout** — overrides default horizontal layout: input on left, chat on right (50/50)
- **Dedicated Pi frame** — `SPC p i f` opens Pi in its own frame
- **Activity phase hooks** — minibuffer messages for "thinking", "replying", "running", "idle"

### `wl-clipboard.el` — Wayland Clipboard

Only activates when all three conditions are met:
1. `window-system` is nil (terminal mode)
2. `XDG_SESSION_TYPE` is `wayland`
3. `wl-copy` and `wl-paste` are in PATH

Uses persistent `wl-copy` process with `-f` flag (required by Wayland's clipboard model).

---

## Complete Keybinding Table

### Global Keybindings (all modes)

| Key | Command | Description |
|---|---|---|
| `C-h` | `centaur-tabs-backward` | Previous tab |
| `C-l` | `centaur-tabs-forward` | Next tab |
| `C-b` | `consult-buffer` | Switch buffer (with Eat source) |
| `M-y` | `consult-yank-pop` | Browse kill-ring |
| `C-x b` | `consult-buffer` | Switch buffer |
| `M-s g` | `consult-grep` | Grep search |
| `M-s l` | `consult-line` | Search in current buffer |
| `M-s r` | `consult-ripgrep` | Ripgrep search |
| `M-s f` | `consult-find` | Find file by name |
| `C-<tab>` | `centaur-tabs-forward` | Next tab |
| `M-<tab>` | `centaur-tabs-forward` | Next tab |
| `C-S-<iso-lefttab>` | `centaur-tabs-backward` | Previous tab |

### Normal Mode — Line Motion

| Key | Command | Description |
|---|---|---|
| `H` | `evil-first-non-blank` | Jump to first non-whitespace on line |
| `L` | `evil-last-non-blank` | Jump to last non-whitespace on line |

### Normal Mode — Avy (Visual Jumping)

| Key | Command | Description |
|---|---|---|
| `s` | `avy-goto-word-1` | Jump to word starting with typed character |
| `S` | `avy-goto-char-2` | Jump to exact 2-character sequence |
| `g s` | `avy-goto-line` | Jump to a visible line number |

### SPC Leader Keybindings

> `SPC` in normal/visual/motion states
> `C-SPC` in insert/emacs states

#### Files (`SPC f`)

| Sequence | Command | Description |
|---|---|---|
| `SPC SPC` | `consult-buffer` | Switch buffer (with Eat terminal source) |
| `SPC f f` | `find-file` | Open file |
| `SPC f r` | `consult-recent-file` | Browse recent files |
| `SPC f s` | `save-buffer` | Save current buffer |
| `SPC f o` | `other-frame` | Switch to another frame |

#### Buffers (`SPC b` / `SPC k`)

| Sequence | Command | Description |
|---|---|---|
| `SPC k k` | `my/switch-to-other-buffer` | Toggle to previous buffer (A ↔ B) |
| `SPC b d` | `kill-current-buffer` | Kill current buffer |
| `SPC b n` | `next-buffer` | Cycle to next buffer |
| `SPC b p` | `previous-buffer` | Cycle to previous buffer |

#### Tabs (`SPC h` / `SPC l`)

| Sequence | Command | Description |
|---|---|---|
| `SPC h` | `centaur-tabs-backward` | Previous tab |
| `SPC l` | `centaur-tabs-forward` | Next tab |

#### Windows (`SPC w`)

| Sequence | Command | Description |
|---|---|---|
| `SPC w v` | `evil-window-vsplit` | Vertical split |
| `SPC w s` | `evil-window-split` | Horizontal split |
| `SPC w d` | `evil-window-delete` | Delete current window |
| `SPC w m` | `delete-other-windows` | Maximize window |
| `SPC w h` | `evil-window-left` | Focus left window |
| `SPC w j` | `evil-window-down` | Focus window below |
| `SPC w k` | `evil-window-up` | Focus window above |
| `SPC w l` | `evil-window-right` | Focus right window |

#### Project (`SPC p`)

| Sequence | Command | Description |
|---|---|---|
| `SPC p p` | `project-switch-project` | Switch project |
| `SPC p f` | `project-find-file` | Find file in project |
| `SPC p g` | `consult-grep` | Grep project files |
| `SPC p b` | `project-switch-to-buffer` | Switch to project buffer |

#### Pi AI Agent (`SPC p i`)

> Requires Pi CLI installed: `npm install -g @earendil-works/pi-coding-agent`

| Sequence | Command | Description |
|---|---|---|
| `SPC p i` | _(prefix group)_ | Show Pi sub-commands via which-key |
| `SPC p i i` | `pi-coding-agent` | Start / focus Pi session |
| `SPC p i f` | `my/pi-frame` | Pi in dedicated frame |
| `SPC p i t` | `pi-coding-agent-toggle` | Toggle Pi windows |
| `SPC p i s` | `pi-coding-agent-open-session-file` | Open session log file |
| `SPC p i m` | `pi-coding-agent-select-model` | Select AI model |

#### Search (`SPC s`)

| Sequence | Command | Description |
|---|---|---|
| `SPC s s` | `consult-line` | Search in current buffer |
| `SPC s g` | `consult-grep` | Grep search |
| `SPC s r` | `consult-ripgrep` | Ripgrep search |

#### Git / Magit (`SPC g`)

| Sequence | Command | Description |
|---|---|---|
| `SPC g g` | `magit-status` | Magit status |
| `SPC g d` | `magit-diff-unstaged` | Show unstaged diff |
| `SPC g l` | `magit-log` | Commit log |
| `SPC g c` | `magit-commit` | Commit |
| `SPC g p` | `magit-push` | Push |
| `SPC g f` | `magit-fetch` | Fetch |
| `SPC g b` | `magit-blame` | Blame at point |
| `SPC g [` | `diff-hl-previous-hunk` | Previous uncommitted hunk |
| `SPC g ]` | `diff-hl-next-hunk` | Next uncommitted hunk |

#### Toggle / Terminal (`SPC t`)

| Sequence | Command | Description |
|---|---|---|
| `SPC t l` | `display-line-numbers-mode` | Toggle line numbers |
| `SPC t w` | `whitespace-mode` | Toggle whitespace visibility |
| `SPC t t` | `my/eat-new` | Spawn new Eat terminal |
| `SPC t p` | `pi-coding-agent-toggle` | Toggle Pi windows |

#### Dired / Navigation (`SPC d`)

| Sequence | Command | Description |
|---|---|---|
| `SPC d d` | `my/dired-from-eat` | Dired from Eat's current directory |

> **Note:** `SPC d f/v/k/m` are help/docs bindings (below). These share the `SPC d` prefix.

#### Help / Docs (`SPC d`)

| Sequence | Command | Description |
|---|---|---|
| `SPC d f` | `describe-function` | Describe a function |
| `SPC d v` | `describe-variable` | Describe a variable |
| `SPC d k` | `describe-key` | Describe a keybinding |
| `SPC d m` | `describe-mode` | Describe current mode |

#### Eglot / LSP (`SPC e`)

| Sequence | Command | Description |
|---|---|---|
| `SPC e a` | `eglot-code-actions` | Code actions at point |
| `SPC e r` | `eglot-rename` | Rename symbol |
| `SPC e f` | `eglot-format` | Format buffer |

#### Org / Notes (`SPC n`)

| Sequence | Command | Description |
|---|---|---|
| `SPC n c` | `org-capture` | Capture note/task |
| `SPC n a` | `org-agenda` | Show Org agenda |

### Pi Input Buffer Keybindings (emacs state)

| Key | Command | Description |
|---|---|---|
| `M-RET` | `pi-coding-agent-send` | Send prompt |
| `S-RET` | `pi-coding-agent-send` | Send prompt |
| `C-c C-c` | `pi-coding-agent-send` | Send prompt |
| `C-c C-s` | `pi-coding-agent-queue-steering` | Queue steering message (interrupts) |
| `C-c C-k` | `pi-coding-agent-abort` | Abort streaming |
| `C-c C-p` | `pi-coding-agent-menu` | Transient menu |
| `C-c C-r` | `pi-coding-agent-resume-session` | Resume previous session |

### Pi Chat Buffer Keybindings (normal state)

| Key | Command | Description |
|---|---|---|
| `q` | `pi-coding-agent-quit` | Quit Pi session |

---

## Theme Reference

### Palette

| Color | Hex | Used For |
|---|---|---|
| Accent | `#ff4400` | Keywords, cursor, Evil search, mode-line, active tab, Avy lead, git branch |
| Accent Alt | `#da4007` | Function names, builtins, links, org-level-2, second Avy lead |
| Strings | `#bf3d0c` | String literals, constants, magit branch remote, org-level-3 |
| Insert BG | `#913716` | Background of Evil substitution matches, insertion overlays |
| Region | `#603120` | Selection/region, mode-line panels, show-paren match bg |
| Highlight | `#462e25` | Line highlight (`hl-line`), inactive mode-line, vertico current |
| Background | `#2b2b2b` | Default background |
| Foreground | `#d4d4d4` | Main text |
| Foreground Alt | `#a0a0a0` | Secondary text, mode-line inactive |
| Comments | `#808080` | Comments, doc strings, borders, inactive tabs |

### Face Groups

| Group | Coverage |
|---|---|
| Core UI | default, cursor, region, hl-line, show-paren, minibuffer-prompt, vertical-border, line-number, header-line, match, link, error/warning/success |
| Syntax | font-lock-keyword/function/type/builtin/string/constant/comment/doc/variable/preprocessor |
| Mode Line | mode-line, mode-line-inactive, mode-line-highlight, mode-line-emphasis |
| Evil | evil-ex-lazy-highlight, evil-search-highlight-persist, evil-ex-substitute-* |
| Vertico/Corfu | vertico-current, vertico-group-title, corfu-* |
| Consult | consult-preview-line, consult-preview-match, consult-file, consult-bookmark |
| Magit | magit-section-heading, magit-branch-*, magit-diff-*, magit-log-*, magit-tag |
| Org | org-level-1 through 5, org-todo, org-done, org-date, org-link, org-block, org-code |
| Doom Modeline | doom-modeline-buffer-modified, doom-modeline-bar, doom-modeline-panel |
| Terminal | term-color-* (ANSI 0-7) |
| Statuscolumn | sc-line-number, sc-separator, sc-bump |
| Diff-hl | diff-hl-margin-insert/delete/change/unknown |
| Centaur Tabs | centaur-tabs-selected/unselected, centaur-tabs-active-bar-face, my/centaur-tabs-group-face |
| Which-key | which-key-key/group-description/command-description/separator |
| Avy | avy-lead-face, avy-lead-face-0/1, avy-background-face |
| Flymake/Eglot | flymake-error/warning/note (wavy underlines), eglot-mode-line |
| Rainbow Delimiters | depths 1-8 + unmatched |
| Dired | dired-directory, dired-header, dired-flagged, dired-marked, dired-symlink |

---

## Quick Start

```bash
# Clone or symlink the config
ln -s /path/to/this/dir ~/.emacs.d
#   OR
git clone <repo-url> ~/.emacs.d

# Launch
emacs -nw
```

### First-time setup

1. **Package installation** — run Emacs; `use-package` with `:ensure t` auto-installs from MELPA
2. **Nerd Font** — `M-x nerd-icons-install-fonts RET` (requires a Nerd Font on your system)
3. **Tree-sitter grammars** — `M-x treesit-install-language-grammar RET` for Python, Julia, etc.
4. **Julia LSP** — `using Pkg; Pkg.add("LanguageServer")` in Julia
5. **Pi CLI** — `npm install -g @earendil-works/pi-coding-agent`, then `pi --login` for auth
6. **Eat shell integration** — Add to `.bashrc`:
   ```bash
   [ -n "$EAT_SHELL_INTEGRATION_DIR" ] && source "$EAT_SHELL_INTEGRATION_DIR/bash"
   ```
7. **wl-clipboard** (Wayland only) — `sudo apt install wl-clipboard` or equivalent

---

## Licence

Part of the `fire_profile` configuration suite.
