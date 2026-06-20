# Emacs Configuration — Minimal + Evil + Doom Modeline

A clean, minimalist Emacs configuration built for **terminal (-nw) use** with Vim emulation at its core. Designed for daily driving in the terminal with a cohesive dark theme, modern minibuffer completion, Git integration, and AI-assisted coding.

**Author:** `fireshark`  
**Palette:** `#2b2b2b` background, `#ff4400` accent  
**Starting:** `emacs -nw` (or set as your `EDITOR`)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File-by-File Reference](#file-by-file-reference)
   - [init.el](#initel)
   - [theme.el](#themeel)
   - [keybinds.el](#keybindsel)
   - [statuscolumn.el](#statuscolumnel)
   - [doom-modeline.el](#doom-modelineel)
   - [centaur-tabs.el](#centaur-tabsel)
   - [diff-hl.el](#diff-hlel)
   - [dirvish.el](#dirvishel)
   - [consult-buffer.el](#consult-bufferel)
   - [vterm.el](#vtermel)
   - [panes.el](#panesel)
   - [pi.el](#piel)
3. [Complete Keybinding Table](#complete-keybinding-table)

---

## Architecture Overview

This config is designed as a **collection of self-contained `.el` files** in a single directory, each responsible for one component. `init.el` orchestrates everything by `require`-ing built-in packages and `load`-ing each custom file by its full path.

| Layer | Packages |
|---|---|
| **Vim emulation** | evil + evil-collection |
| **Leader key** | general (SPC / C-SPC) |
| **Completion** | vertico + marginalia + consult |
| **Git** | magit + diff-hl |
| **AI Coding Agent** | pi-coding-agent |
| **LSP** | eglot (built-in) |
| **File manager** | dirvish (dired replacement) |
| **Tabs** | centaur-tabs |
| **Modeline** | doom-modeline |
| **Terminal** | vterm (libvterm bindings) |
| **Navigation** | avy |
| **Notes** | org-mode |
| **Key discovery** | which-key |

### Dependency Graph

```
init.el
 ├── doom-modeline.el        (doom-modeline + nerd-icons)
 ├── statuscolumn.el         (custom visual-line-number overlays)
 ├── vterm.el                (emacs-libvterm config)
 ├── diff-hl.el              (uncommitted change indicators)
 ├── keybinds.el             (ALL leader and normal keybindings)
 ├── consult-buffer.el       (custom consult sources, depends on keybinds.el functions)
 ├── panes.el                (vertical border glyph)
 ├── centaur-tabs.el         (tab bar with group labels)
 ├── dirvish.el              (modern file manager)
 ├── pi.el                   (Pi coding agent integration)
 └── theme.el                (firebat theme definition)
```

---

## File-by-File Reference

### `init.el`

**Role:** Bootstrap and orchestration.

This is the entry point. It:

1. Configures **package management** (MELPA, `use-package` with `:ensure t`)
2. Sets **sane defaults** — disables GUI bars, enables `show-paren-mode`, `global-auto-revert-mode`, `save-place-mode`, `recentf-mode`, deletes trailing whitespace on save, remaps backups to `~/.emacs.d/backups/`
3. Loads **evil** and **evil-collection** — Vim emulation everywhere
4. Sets up **general** for the SPC leader key (delegates actual bindings to `keybinds.el`)
5. Loads **which-key** to show available bindings after a 0.5s delay
6. Loads each custom `.el` file via `(load (expand-file-name "file.el" real-dir))` — note the `load` pattern that resolves the file relative to the config directory
7. Provides **language support** for Julia and Python via `eglot` (LSP) and `treesit` (tree-sitter syntax highlighting)
8. Configures **Org mode** with capture templates, TODO keywords, and agenda files
9. Sets up **Avy** for visual character jumping
10. Loads and enables the **firebat theme**

**Key settings:**
- `evil-want-keybinding nil` — delegates keybinding setup to evil-collection
- `evil-undo-system 'undo-redo` — modern undo-redo (Emacs 28+)
- `gc-cons-threshold` bumped to 100 MB during startup, reset to 800 KB after
- `eglot-autoshutdown t` — kill LSP when last buffer closes

---

### `theme.el`

**Role:** Full custom theme definition — the **firebat** theme.

A terminal-optimised dark theme with a consistent 7-stop gradient:

```
#ff4400  →  #da4007  →  #bf3d0c  →  #913716  →  #603120  →  #462e25  →  #2b2b2b
(bright accent)                                          (selection)    (bg)
```

Defines faces for **every component** in the config:

| Face Group | What's Covered |
|---|---|
| Core UI | `default`, `cursor`, `region`, `hl-line`, `show-paren`, `minibuffer-prompt`, `vertical-border`, `line-number`, `header-line`, `match`, `link` |
| Syntax | `font-lock-*` — keywords, functions, types, strings, comments, etc. |
| Mode Line | `mode-line`, `mode-line-inactive`, `mode-line-highlight` |
| Evil | search highlights, ex-substitute matches |
| Vertico/Corfu | completion UI faces |
| Consult | preview lines, matches, file/bookmark colours |
| Magit | branches, diffs, section headings, log graph |
| Org | heading levels, TODOs, blocks, tables, links |
| Doom Modeline | modified, major-mode, bar, panel, project dir |
| Terminal | `term-*` ANSI colour map |
| Statuscolumn | `sc-line-number`, `sc-separator`, `sc-bump` |
| Diff-hl | margin insert/delete/change icons |
| Centaur Tabs | selected/unselected tabs, group label, modified markers, active bar |
| Which-key | key, group, command, separator, note faces |
| Avy | lead faces (1-character and 2-character highlight) |
| Flymake/Eglot | squiggly underline colours for errors/warnings/notes |
| Rainbow Delimiters | 8 depth levels + unmatched |
| Dired/Dirvish | directories, headers, symlinks, marks, `dirvish-hl-line` |

The theme is `deftheme`-based, loaded with `(enable-theme 'firebat)` in `init.el`. All faces can be overridden with `custom-theme-set-faces`.

---

### `keybinds.el`

**Role:** Central registry of **all custom keybindings**.

Uses the `leader` definer from `init.el` (based on `general.el`) which maps:

- `SPC` as prefix in **normal / visual / motion** states
- `C-SPC` as prefix in **insert / emacs** states (so SPC still inserts a space)

Additionally defines normal-mode bindings for window navigation, line motion, and Avy.

**⚠️ Note:** The `SPC d f` binding is used for **both** `dirvish-fd` and `describe-function` — the latter will shadow the former in practice since it's defined second. Dirvish' own mode-map overrides this inside dirvish buffers.

Also defines several utility functions:
- `my/vterm-new` — spawns a vterm at the lowest available index
- `my/switch-to-other-buffer` — toggles between two most recent buffers
- `my/buffer-goto` — jump to a buffer by index number (typed interactively)
- `my/vterm-goto` — jump to or spawn a vterm by index number

**Pi keybindings** are defined in separate `with-eval-after-load` blocks for the `pi-coding-agent-input-mode-map` and `pi-coding-agent-chat-mode-map`.

See the [Complete Keybinding Table](#complete-keybinding-table) below for every binding.

---

### `statuscolumn.el`

**Role:** Custom visual line-number column using overlays.

Replaces the built-in `display-line-numbers-mode` with a fully custom implementation. Every **visual** (displayed) line gets a padded number and a separator character:

- Most lines: `  NN ┃` (separator face `sc-separator`, dim grey)
- Current line: `  NN ┣` (bump face `sc-bump`, bold accent)
- All visual continuation lines of the current logical line get `┣`

**Features:**
- Dynamic width — pads to fit the largest line number in the buffer (minimum 5 chars)
- Works with wrapped lines — each visual line gets its own overlay
- Excluded modes: `pi-coding-agent-chat-mode`, `pi-coding-agent-input-mode` (from `sc-excluded-modes`)
- Uses `post-command-hook`, `window-scroll-functions`, and `after-change-functions` to refresh
- Overlay-based — no `linum-mode` or `display-line-numbers-mode` interference
- Cannot be toggled off (intentionally always-on)

---

### `doom-modeline.el`

**Role:** Customises the Doom Modeline to match the firebat aesthetic.

Customises every aspect of the modeline:
- **Custom percentage indicator** — an 8-level Nerd Font scrollbar glyph (󰰗 → 󰪥) instead of a numeric percentage, placed before the buffer name
- **Custom buffer-info segment** — shows buffer name + state icon (modified, read-only) without the mode icon (you already know what mode you're in)
- **Redefined main modeline** — left side: `eldoc bar window-state workspace-name window-number modals matches follow <percent> <buffer-info> remote-host`; right side: `compilation objed-state misc-info project-name persp-name battery… check time`
- Nerd Font icons required — uses `nerd-icons` package

---

### `centaur-tabs.el`

**Role:** Aesthetic tab bar with group labels and git status.

Provides a modern tab bar at the top of each frame. Key customisations:
- **Group name segment** — prepended to the tab bar, shows  `<branch>:<hash>` for project groups, or an icon + group name for others ( Elisp,  Magit,  Shell,  Dired,  Org)
- **Custom tab labels** — active tabs get `█ filename ` (with inverted bar-style highlight), inactive tabs get ` filename `; modified files get a 󱍸 prefix
- **Git branch cache** — branch:hash info is cached per project path and invalidated on buffer switch
- **Styling** — "bar" style (clean in terminal), underline active bar, height 24, no close buttons, no left/right margins
- **Group face** — `my/centaur-tabs-group-face` (accent foreground, bg background)
- Hides tabs in `help-mode` and `apropos-mode`
- Tab cycling via `M-<tab>`, `C-<tab>`, `C-S-<iso-lefttab>`

---

### `diff-hl.el`

**Role:** Visual change indicators in the left margin.

Highlights uncommitted changes (insertions, deletions, modifications) in file-visiting buffers using Nerd Font icons:

| Change | Icon |
|---|---|
| Insertion | ` ` |
| Deletion | ` ` |
| Modification | ` 󱍸` |
| Unknown | ` ┆` |
| Ignored | ` i` |

**Integration:**
- Global `diff-hl-mode` in all file buffers
- `diff-hl-dired-mode` in dired buffers (shows changed files)
- `diff-hl-flydiff-mode` — updates indicators as you type (not just on save)
- `diff-hl-margin-mode` — uses a 2-character wide left margin
- Magit integration — refreshes after commit/push/pull via `magit-post-refresh-hook`

---

### `dirvish.el`

**Role:** Modern file manager replacing Dired.

Dirvish enhances Emacs' built-in Dired with file previews, multiple layouts, VC integration, and a polished UI. It's inspired by ranger.

**Layout:** `'(0 0.11 0.55)` — 2-panel layout (file listing | preview pane), no parent directory windows.

**Features enabled:**
- File attributes inline: `file-size`, `subtree-state`, `collapse`
- Mode line with sort/symlink info on left, omit/index on right
- Header line with path + free space
- Quick-access entries for `~/`, `~/Downloads/`, config modules, `/mnt/`
- File preview dispatchers for images, video, audio, PDF, EPUB, archives, fonts
- Async directory opening via `fd` for directories > 20,000 files
- Renamed `dired-mode` keybindings (?, a, f, o, s, r, l, v, y, *, N, ^, TAB, M-f, M-b, M-e)

**Dired base settings:** `-l --almost-all --human-readable --group-directories-first --no-group` listing switches, trash-based deletion, mouse drag-and-drop.

---

### `consult-buffer.el`

**Role:** Custom `consult-buffer` sources.

Currently defines one custom source — **VTerm source**:

- Adds vterm buffers as candidates in `SPC SPC` (`consult-buffer`)
- Typing a number spawns a new vterm at that index (e.g., typing `5` creates vterm index 5)
- Existing vterm buffers appear as selectable candidates
- Marked as `:default t` and prepended to `consult-buffer-sources` so it's checked first before creating a regular buffer

Depends on `my/vterm-spawn-at-index` and `my/vterm-buffer-list` from `keybinds.el`.

---

### `vterm.el`

**Role:** Terminal emulator configuration (emacs-libvterm).

- Vim-by-default — starts in evil **NORMAL** state; `i` enters insert state
- **Cursor snap** — advises `evil-collection-vterm-insert` and `-insert-line` to send a space+backspace to the terminal, forcing the cursor to snap to the correct position visually
- **Shell integration** — directory tracking via the `etc/emacs-vterm-bash.sh` script, sourced in `.bashrc`
- Loaded via `require 'vterm-autoloads` because it's installed via NixOS, not MELPA

---

### `panes.el`

**Role:** Window divider aesthetics in terminal mode.

Replaces the default `|` vertical border character with `┼` (Unicode U+253C) using the display table. Also hooks into `vterm-mode-hook` to re-apply the glyph in vterm buffers (which set their own buffer-local display table).

---

### `pi.el`

**Role:** Integration with the Pi Coding Agent CLI.

Provides an Emacs frontend for [Pi](https://pi.dev) — an AI coding agent. Key features:

- **Convenience alias** — `M-x pi` starts/focuses Pi (alias for `pi-coding-agent`)
- **Vertical split layout** — overrides the default horizontal layout so the chat occupies the left pane and the prompt/composition buffer is on the right (50/50 split)
- **Dedicated Pi frame** — `my/pi-frame` opens Pi in its own Emacs frame
- **Activity phase hooks** — minibuffer messages for "thinking"/"replying"/"running"/"idle" transitions
- **Customisable settings** — input window height, preview lines, RPC timeout, context thresholds, Markdown highlighting in input buffer, pipe table prettification

**Input buffer keybindings:**
- `M-RET` / `S-RET` / `C-c C-c` — send prompt
- `C-c C-s` — queue steering message
- `C-c C-k` — abort streaming
- `C-c C-p` — transient menu
- `C-c C-r` — resume session

**Chat buffer keybindings:**
- `q` — quit session (normal mode)

---

## Complete Keybinding Table

### Normal Mode — Window Navigation

| Key | Command | Description |
|---|---|---|
| `C-h` | `evil-window-left` | Move focus to left window |
| `C-j` | `evil-window-down` | Move focus to window below |
| `C-k` | `evil-window-up` | Move focus to window above |
| `C-l` | `evil-window-right` | Move focus to right window |

### Normal Mode — Line Motion

| Key | Command | Description |
|---|---|---|
| `H` | `evil-first-non-blank` | Jump to first non-whitespace character on line |
| `L` | `evil-last-non-blank` | Jump to last non-whitespace character on line |

**Applicable states:** `normal`, `visual`, `visual-block`, `visual-line`

### Normal Mode — Avy (Visual Jumping)

| Key | Command | Description |
|---|---|---|
| `s` | `avy-goto-word-1` | Jump to word starting with a typed character |
| `S` | `avy-goto-char-2` | Jump to exact two-character sequence |
| `g s` | `avy-goto-line` | Jump to a visible line number |

### SPC Leader Keybindings

The leader key is `SPC` in normal/visual/motion states, `C-SPC` in insert/emacs states.

#### Files (`SPC f`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC SPC` | `consult-buffer` | Switch buffer (with vterm & file sources) |
| `SPC f f` | `find-file` | Open a file |
| `SPC f r` | `consult-recent-file` | Browse recently opened files |
| `SPC f s` | `save-buffer` | Save current buffer |
| `SPC f o` | `other-frame` | Switch to another Emacs frame |

#### Buffers (`SPC b`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC k k` | `my/switch-to-other-buffer` | Toggle to previous buffer (A ↔ B) |
| `SPC b d` | `kill-current-buffer` | Kill current buffer |
| `SPC b n` | `next-buffer` | Cycle to next buffer |
| `SPC b p` | `previous-buffer` | Cycle to previous buffer |
| `SPC b 0-9` | `my/buffer-goto` | Jump to buffer by index number |

#### Tabs (`SPC h` / `SPC l`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC h` | `centaur-tabs-backward` | Previous tab |
| `SPC l` | `centaur-tabs-forward` | Next tab |

#### Windows (`SPC w`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC w v` | `evil-window-vsplit` | Vertical split |
| `SPC w s` | `evil-window-split` | Horizontal split |
| `SPC w d` | `evil-window-delete` | Delete current window |
| `SPC w m` | `delete-other-windows` | Maximise current window |
| `SPC w h` | `evil-window-left` | Focus left window |
| `SPC w j` | `evil-window-down` | Focus window below |
| `SPC w k` | `evil-window-up` | Focus window above |
| `SPC w l` | `evil-window-right` | Focus right window |

#### Project (`SPC p`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC p p` | `project-switch-project` | Switch to another project |
| `SPC p f` | `project-find-file` | Find file in current project |
| `SPC p g` | `consult-grep` | Grep across project files |
| `SPC p b` | `project-switch-to-buffer` | Switch to a project buffer |

#### Pi Coding Agent (`SPC p i`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC p i` | — | Pi prefix group (shows sub-commands) |
| `SPC p i i` | `pi-coding-agent` | Start / focus Pi session |
| `SPC p i f` | `my/pi-frame` | Open Pi in a dedicated frame |
| `SPC p i t` | `pi-coding-agent-toggle` | Toggle Pi session windows |
| `SPC p i s` | `pi-coding-agent-open-session-file` | Open session log file |
| `SPC p i m` | `pi-coding-agent-select-model` | Select AI model |

#### Search (`SPC s`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC s s` | `consult-line` | Search within current buffer |
| `SPC s g` | `consult-grep` | Grep search in project |
| `SPC s r` | `consult-ripgrep` | Ripgrep search in project |

#### Git / Magit (`SPC g`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC g g` | `magit-status` | Magit status buffer |
| `SPC g d` | `magit-diff-unstaged` | Show unstaged diff |
| `SPC g l` | `magit-log` | Show commit log |
| `SPC g c` | `magit-commit` | Commit staged changes |
| `SPC g p` | `magit-push` | Push to remote |
| `SPC g f` | `magit-fetch` | Fetch from remote |
| `SPC g b` | `magit-blame` | Git blame at point |
| `SPC g [` | `diff-hl-previous-hunk` | Go to previous uncommitted hunk |
| `SPC g ]` | `diff-hl-next-hunk` | Go to next uncommitted hunk |

#### Toggle (`SPC t`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC t l` | `display-line-numbers-mode` | Toggle line numbers (redundant with statuscolumn) |
| `SPC t w` | `whitespace-mode` | Toggle whitespace visibility |
| `SPC t t` | `my/vterm-new` | Spawn a new vterm at the lowest available index |
| `SPC t p` | `pi-coding-agent-toggle` | Toggle Pi session windows |

#### Dirvish (`SPC d`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC d d` | `dirvish` | Open Dirvish file manager |
| `SPC d s` | `dirvish-side` | Toggle Dirvish sidebar |
| `SPC d f` | `dirvish-fd` | Dirvish fd search (**note:** conflicts with `describe-function` below) |
| `SPC d D` | `dirvish-dispatch` | Dirvish cheatsheet / transient menu |
| `SPC d q` | `dirvish-quit` | Close Dirvish session |

#### Help / Docs (`SPC d`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC d f` | `describe-function` | Describe a function (**note:** conflicts with `dirvish-fd` above) |
| `SPC d v` | `describe-variable` | Describe a variable |
| `SPC d k` | `describe-key` | Describe a keybinding |
| `SPC d m` | `describe-mode` | Describe current major/minor modes |

> **⚠️ Note:** The `SPC d f` binding is shared by both `dirvish-fd` and `describe-function`. In practice, `describe-function` (defined second in `keybinds.el`) will shadow `dirvish-fd` at the global level. Dirvish' own mode-map still binds it inside Dirvish buffers.

#### Eglot / LSP (`SPC e`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC e a` | `eglot-code-actions` | Show code actions at point |
| `SPC e r` | `eglot-rename` | Rename symbol |
| `SPC e f` | `eglot-format` | Format buffer |

#### Org / Notes (`SPC n`)

| Key Sequence | Command | Description |
|---|---|---|
| `SPC n c` | `org-capture` | Capture a new note/task |
| `SPC n a` | `org-agenda` | Show Org agenda |

### Pi Input Buffer (emacs state)

| Key | Command | Description |
|---|---|---|
| `M-RET` | `pi-coding-agent-send` | Send prompt to Pi |
| `S-RET` | `pi-coding-agent-send` | Send prompt to Pi |
| `C-c C-c` | `pi-coding-agent-send` | Send prompt to Pi |
| `C-c C-s` | `pi-coding-agent-queue-steering` | Queue a steering message (interrupts current tool) |
| `C-c C-k` | `pi-coding-agent-abort` | Abort streaming response |
| `C-c C-p` | `pi-coding-agent-menu` | Open transient menu (model, sessions, commands) |
| `C-c C-r` | `pi-coding-agent-resume-session` | Resume a previous session |

### Pi Chat Buffer (normal state)

| Key | Command | Description |
|---|---|---|
| `q` | `pi-coding-agent-quit` | Quit Pi session |

### Dirvish Mode Map

Key | Command | Description
---|---|---
`?` | `dirvish-dispatch` | Cheatsheet / transient menu
`a` | `dirvish-setup-menu` | Attribute settings
`f` | `dirvish-file-info-menu` | File info
`o` | `dirvish-quick-access` | Quick-access bookmarks
`s` | `dirvish-quicksort` | Sort menu
`r` | `dirvish-history-jump` | History navigation
`l` | `dirvish-ls-switches-menu` | Live ls switch toggling
`v` | `dirvish-vc-menu` | Version control menu
`y` | `dirvish-yank-menu` | Copy/paste menu
`*` | `dirvish-mark-menu` | Mark menu
`N` | `dirvish-narrow` | Narrow / fd search
`^` | `dirvish-history-last` | Go to parent directory via history
`TAB` | `dirvish-subtree-toggle` | Toggle subtree expand/collapse
`M-f` | `dirvish-history-go-forward` | History forward
`M-b` | `dirvish-history-go-backward` | History back
`M-e` | `dirvish-emerge-menu` | Emerge (ibuffer-like grouping)

---

## Quick Start

```bash
# Clone the config
git clone <this-repo> ~/.emacs.d   # or symlink to it

# Install dependencies (NixOS example)
# Add to environment.systemPackages:
#   emacsPackages.vterm
#   emacsPackages.nerd-icons

# Ensure Pi CLI is installed (optional)
npm install -g @earendil-works/pi-coding-agent

# Launch
emacs -nw
```

### First-Time Setup

1. **Package installation:** `use-package` with `:ensure t` will auto-install packages from MELPA on first run.
2. **Nerd Font:** Install a Nerd Font (e.g., `Symbols Nerd Font Mono`) for mode-line and diff-hl icons via `M-x nerd-icons-install-fonts`.
3. **Vterm:** The vterm library (`emacs-libvterm`) is a native module — on NixOS, install via `emacsPackages.vterm`.
4. **Tree-sitter grammars:** Run `M-x treesit-install-language-grammar` for Python, Julia, etc.
5. **Julia LSP:** `using Pkg; Pkg.add("LanguageServer")` in Julia.
6. **Dirvish:** `M-x package-install RET dirvish RET`.
7. **Pi CLI:** See [pi.dev](https://pi.dev) for authentication setup.

---

## Licence

Part of the `fire_profile` configuration suite. Use freely, modify at will.
