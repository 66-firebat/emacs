# 🔥 Emacs Configuration — Firebat Edition

A terminal-first Emacs config with **Evil** (Vim emulation), **Eat** terminal emulator, **permanent avy-style jump labels** in the statuscolumn, **Doom Modeline**, **Centaur Tabs**, and **Pi** AI coding agent. Built for the `firebat` theme (`#2b2b2b` background, `#ff4400` accent).

**Author:** `fireshark` · **Launch:** `emacs -nw`

---

## Keybindings Quick Reference

### Jump / Navigation

| Key | Mode | Command | Description |
|-----|------|---------|-------------|
| `f` | normal/visual | `avy-goto-char-2` | Type 2 chars, jump to any visible match |
| `;` | normal/visual | `sc-avy-goto-line` | Type statuscolumn label to jump to line |
| `gs` | normal/visual | `sc-avy-goto-line` | Same as `;` |
| `S` | normal/visual | `avy-goto-char-2` | Uppercase variant |
| `H` | normal/visual | `evil-first-non-blank` | First non-whitespace on line |
| `L` | normal/visual | `evil-last-non-blank` | Last non-whitespace on line |
| `C-o` | normal | `evil-jump-backward` | Jump back in global jump ring |
| `C-i` | normal | `evil-jump-forward` | Jump forward in global jump ring |
| `C-u` | normal/visual | `evil-scroll-up` | Scroll up 1/2 screen (animated) |
| `C-d` | normal/visual | `evil-scroll-down` | Scroll down 1/2 screen (animated) |
| `C-f` | normal/visual | `evil-scroll-page-down` | Scroll down full page (animated) |
| `C-y` | normal/visual | `evil-scroll-line-up` | Scroll up 1 line (animated) |
| `C-e` | normal/visual | `my/dired-from-eat` | Dired at Eat's cwd (overrides scroll-down) |

### Tab & Buffer Switching

| Key | Command | Description |
|-----|---------|-------------|
| `C-h` | `centaur-tabs-backward` | Previous tab |
| `C-l` | `centaur-tabs-forward` | Next tab |
| `C-b` | `consult-buffer` | Switch buffer (Eat terminals included) |
| `C-<tab>` | `centaur-tabs-forward` | Next tab |
| `M-<tab>` | `centaur-tabs-forward` | Next tab |
| `C-S-<iso-lefttab>` | `centaur-tabs-backward` | Previous tab |

### SPC Leader (`SPC` in normal/visual, `C-SPC` in insert)

#### Files & Buffers

| Key | Command | Description |
|-----|---------|-------------|
| `SPC SPC` | `consult-buffer` | Switch buffer (with Eat terminal source) |
| `SPC f f` | `find-file` | Open file |
| `SPC f r` | `consult-recent-file` | Recent files |
| `SPC f s` | `save-buffer` | Save |
| `SPC f o` | `other-frame` | Other frame |
| `SPC k k` | `my/switch-to-other-buffer` | Toggle A ↔ B |
| `SPC b d` | `kill-current-buffer` | Kill buffer |
| `SPC b n/p` | `next/previous-buffer` | Cycle buffers |

#### Windows

| Key | Command |
|-----|---------|
| `SPC w v` | `evil-window-vsplit` |
| `SPC w s` | `evil-window-split` |
| `SPC w d` | `evil-window-delete` |
| `SPC w m` | `delete-other-windows` |
| `SPC w h/j/k/l` | `evil-window-left/down/up/right` |

#### Search

| Key | Command |
|-----|---------|
| `SPC s s` | `consult-line` |
| `SPC s g` | `consult-grep` |
| `SPC s r` | `consult-ripgrep` |

#### Git (Magit)

| Key | Command |
|-----|---------|
| `SPC g g` | `magit-status` |
| `SPC g d/l/c/p/f/b` | diff/log/commit/push/fetch/blame |
| `SPC g [/]` | `diff-hl-previous/next-hunk` |

#### Terminal & Toggle

| Key | Command | Description |
|-----|---------|-------------|
| `SPC t t` | `my/eat-new` | Spawn new Eat terminal |
| `SPC t l` | `display-line-numbers-mode` | Toggle line numbers |
| `SPC t w` | `whitespace-mode` | Toggle whitespace |
| `SPC t p` | `pi-coding-agent-toggle` | Toggle Pi windows |

#### Project

| Key | Command |
|-----|---------|
| `SPC p p/f/g/b` | project-switch/find-file/grep/buffer |

#### Pi AI Agent

| Key | Command |
|-----|---------|
| `SPC p i i` | `pi-coding-agent` — Start/focus Pi |
| `SPC p i f` | `my/pi-frame` — Pi in dedicated frame |
| `SPC p i t` | `pi-coding-agent-toggle` |
| `SPC p i s` | Open session file |
| `SPC p i m` | Select model |

#### Help & LSP

| Key | Command |
|-----|---------|
| `SPC d f/v/k/m` | describe-function/variable/key/mode |
| `SPC d d` | `my/dired-from-eat` — Dired at Eat's cwd |
| `SPC e a/r/f` | eglot-code-actions/rename/format |

#### Org

| Key | Command |
|-----|---------|
| `SPC n c` | `org-capture` |
| `SPC n a` | `org-agenda` |

### Pi Input Buffer (`emacs` state)

| Key | Command |
|-----|---------|
| `M-RET` / `S-RET` / `C-c C-c` | Send prompt |
| `C-c C-s` | Queue steering (interrupt) |
| `C-c C-k` | Abort |
| `C-c C-p` | Menu |
| `C-c C-r` | Resume session |

---

## What's Inside

### `statuscolumn.el` — Permanent Letter Jump Labels

Replaces Emacs' built-in line numbers with permanent letter-based jump labels in the statuscolumn.

**Layout:** `[diff-hl margin icon] [mark] [space] [label] [padding] [separator] [space] [buffer text]`

| Type | Example | Width |
|------|---------|-------|
| Non-current line | ` a  ┃ text` | 7 chars |
| Current line | ` 󰪟 ┣ text` | 7 chars |
| Non-current wrap | `   ┃ text` | 7 chars |
| Current wrap | `   ┣ text` | 7 chars |
| With mark | ` a a┃ text` | 7 chars |

**Design:**
- Runs `sc--init` on **every** `post-command-hook` for simplicity and correctness
- Deletes ALL overlays and creates fresh ones each time — no flicker because redisplay runs *between* commands, not within them
- `window-scroll-functions` hook catches auto-scrolling during redisplay
- `window-size-change-functions` hook catches window resizes
- `eat-update-hook` integration refreshes labels immediately after Eat terminal output (which bypasses the command loop)

**Wrap icon:**
- Continuation lines show `    ┃ ` on non-current lines and `    ┣ ` on current lines
-  uses `#ff4400` (orange) for current-line wraps, `#444444` (gray) for non-current wraps

### `jumpring.el` — Global Jump Ring

Overrides Evil's per-window jump list with a **single global jump ring** shared across all windows and buffers.

- `C-o` / `C-i` navigate the same history regardless of which window you're in
- Jumps in non-file buffers (Eat terminals, `*scratch*`) are properly saved using the buffer name
- When jumping back to a non-file buffer, `switch-to-buffer` is used instead of `find-file`
- Default capacity: **100 jumps** (configurable via `evil-jumps-max-length`)

### `neoscroll.el` — Smooth Animated Scrolling

Bundles the [neoscroll.el](https://github.com/0WD0/neoscroll.el) library (v1.0.0) with custom configuration. Intercepts Evil's scroll commands and animates them with easing functions.

**Overridden commands:**

| Key | Evil command | Replaced with | Scroll amount |
|-----|-------------|---------------|---------------|
| `C-u` | `evil-scroll-up` | `neoscroll-ctrl-u` | half window up |
| `C-d` | `evil-scroll-down` | `neoscroll-ctrl-d` | half window down |
| `C-b` | `evil-scroll-page-up` | `neoscroll-ctrl-b` | full page up |
| `C-f` | `evil-scroll-page-down` | `neoscroll-ctrl-f` | full page down |
| `C-y` | `evil-scroll-line-up` | `neoscroll-ctrl-y` | 1 line up (cursor stays) |
| `C-e` | `evil-scroll-line-down` | `neoscroll-ctrl-e` | 1 line down (cursor stays) |

**Easing functions available:** `linear`, `quadratic` (current), `cubic`, `sine`

All distribute a fixed time budget (e.g. 150ms for C-u) across frames. The easing function controls how time slices are allocated — fast frames early (ease-out) or evenly (linear).

**Statuscolumn integration:** After each animation step, `sc--init` is called to keep jump labels in sync with scrolled content.

**Timings:**
- `neoscroll-scroll-duration` — 0.15s (C-u/C-d half-page)
- `neoscroll-page-duration` — 0.25s (C-f/C-b full-page)
- `neoscroll-line-duration` — 0.025s (C-y/C-e single-line)

### `eat.el` — Terminal Emulator

- **Shell integration** — OSC 7 directory tracking (updates `default-directory` on `cd`)
- **Statuscolumn-aware** — Custom `window-adjust-process-window-size-function` subtracts **7 characters** for the label+separator prefix
- **Unlimited scrollback** — `eat-term-scrollback-size nil` preserves the entire terminal session history (default 128 KB limit removed)
- **Input mode** — `semi-char` (most keys sent to terminal, special keys handled by Emacs)
- **Multiple terminals** — Indexed tabs (`0 `, `1 `, `2 `...) via `SPC t t`

### `doom-modeline.el` — Custom Mode Line

- **Line number** — Shows `L42` before the buffer name (replaces old scrollbar percentage)
- **Buffer-info** — Buffer name + state icon (modified/read-only), no mode icon
- **Layout** — Left: `eldoc bar workspace window-number modals matches follow <line-num> <buffer-info>` | Right: misc-info, project, battery, etc.

### `diff-hl.el` — Change Indicators

Nerd Font icons in the left margin: ` ` (insert), ` ` (delete), ` 󱍸` (modify), ` ┆` (unknown). Enabled globally with live-updating via `flydiff`.

### `theme.el` — Firebat Theme

Full custom `deftheme` with 7-stop gradient palette:

```
#ff4400  →  #da4007  →  #bf3d0c  →  #913716  →  #603120  →  #462e25  →  #2b2b2b
(accent)                                  (selection)                  (bg)
```

Faces for: Core UI, syntax highlighting, mode-line, Evil search, Vertico/Consult, Magit, Org, Doom Modeline, Eat terminal ANSI, Statuscolumn, Diff-hl, Centaur Tabs, Which-key, Avy, Flymake/Eglot, Rainbow Delimiters, Dired.

### `evil-cursor.el` — Per-State Terminal Cursor

Changes the terminal cursor shape/color per Evil state:
- **Normal:** Green block
- **Insert:** Orange bar
- **Visual:** Blue underline
- **Replace:** Red hollow

### `centaur-tabs.el` — Tab Bar

Shows tabs at the top with group labels (` branch:hash` for project files, `` for Elisp, `` for Shell, etc.). Active tab uses `█` / `` separators, modified files get `󱍸` prefix.

### `consult-buffer.el` — Buffer Source

Adds an **Eat terminal source** to `consult-buffer`. Eat buffers appear as completions, and typing a number spawns a new Eat at that index.

### `dired.el` — Dired Customizations

Hide details (`dired-hide-details-mode`), human-readable sizes, `-lah` as default listing switch.

### `panes.el` — Window Dividers

Replaces vertical border `|` with `┼` via display table.

### `pi.el` — Pi AI Coding Agent

Integration with the Pi coding agent: vertical split layout, dedicated frame support, activity-phase minibuffer messages.

### `wl-clipboard.el` — Wayland Clipboard

Seamless clipboard for terminal Emacs on Wayland using `wl-copy`/`wl-paste`.

---

## File-by-File Load Order

| # | File | Description |
|---|------|-------------|
| 1 | `init.el` | Bootstrap, package management, sane defaults, scroll behavior |
| 2 | `evil-cursor.el` | Per-state terminal cursor |
| 3 | `doom-modeline.el` | Custom mode line |
| 4 | `consult-buffer.el` | Consult + Eat buffer source |
| 5 | `embark.el` | Context-aware minibuffer actions |
| 6 | `dired.el` | Dired customizations |
| 7 | `panes.el` | Window divider glyphs |
| 8 | `statuscolumn.el` | Permanent letter jump labels |
| 9 | `neoscroll.el` | Smooth animated scrolling |
| 10 | `jumpring.el` | Global Evil jump ring |
| 11 | `eat.el` | Terminal emulator |
| 12 | `diff-hl.el` | Change indicators |
| 13 | `centaur-tabs.el` | Tab bar |
| 14 | `keybinds.el` | All custom keybindings |
| 15 | `pi.el` | Pi AI agent |
| 16 | `wl-clipboard.el` | Wayland clipboard |
| 17 | `theme.el` | Firebat theme |

---

## Configuration Highlights

### Scroll Behavior

- `scroll-conservatively 101` — never recenter cursor when scrolling past window edges (equivalent of Vim's `scrolloff=0`)
- `scroll-margin 0` — no auto-scroll margin at window edges

### Evil

- `evil-want-keybinding nil` — delegates to evil-collection
- `evil-undo-system 'undo-redo` — modern undo/redo
- `evil-want-C-i-jump t` — `C-i` jumps forward
- `evil-want-C-u-scroll t` — `C-u` scrolls up
- `evil-want-Y-yank-to-eol t` — `Y` yanks to end of line

### Avy

- `avy-style 'at-full` — shows full candidate text
- `avy-background t` — dims rest of buffer
- `avy-all-windows 'all` — searches all windows
- `avy-keys` — home row (`a s d f g h j k l`)

### Vertico + Consult

- `vertico-mode`, `marginalia-mode` — vertical completion with annotations
- `consult-buffer` includes Eat terminals, bookmarks, recent files
- `consult-line`, `consult-grep`, `consult-ripgrep` for search
- `consult-yank-pop` on `M-y`
- `consult-find` on `M-s f`

### Diff-hl

- `diff-hl-flydiff-mode` — live indicators (not just on save)
- `diff-hl-dired-mode` — indicators in Dired
- Magit refresh hook — updates after commit/push/pull

### Eglot (LSP)

- `eglot-autoshutdown t` — kills LSP when last buffer closes
- Managed via `eglot.el` in each project root
- Julia: requires `LanguageServer.jl`

---

## Quick Start

```bash
# Launch
emacs -nw
```

### First-time setup

1. **Packages** auto-install via `use-package` with `:ensure t`
2. **Nerd Font** — `M-x nerd-icons-install-fonts RET`
3. **Tree-sitter** — `M-x treesit-install-language-grammar RET` for Python, Julia, etc.
4. **Eat shell integration** — add to `~/.bashrc`:
   ```bash
   [ -n "$EAT_SHELL_INTEGRATION_DIR" ] && source "$EAT_SHELL_INTEGRATION_DIR/bash"
   ```
5. **Pi CLI** — `npm install -g @earendil-works/pi-coding-agent && pi --login`
6. **Wayland clipboard** — `sudo apt install wl-clipboard`

---

## Known Issues

- `SPC d` prefix shared between Dired (`SPC d d`) and help/docs (`SPC d f/v/k/m`)
- `wl-clipboard.el` only works on Wayland (no X11/macOS fallback)
- `rainbow-delimiters` faces defined but package not installed
