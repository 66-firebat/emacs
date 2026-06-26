# Firemacs

A terminal-first Emacs configuration with Evil (Vim emulation), a custom statuscolumn with permanent letter jump labels, MRU-based tab bar, smooth scrolling, and integrated terminal emulator. Built for the Firebat theme (#2b2b2b background, #ff4400 accent).

Launch with: `emacs -nw`

---

## Keybindings

### Jump / Navigation

| Key | Modes | Command | Action |
|-----|-------|---------|--------|
| `f` | normal, visual | sc-avy-goto-char-2 | Jump to visible character pair |
| `;` | normal, visual | sc-avy-goto-line | Jump to line by statuscolumn label |
| `gs` | normal, visual | sc-avy-goto-line | Jump to line by statuscolumn label |
| `S` | normal, visual | consult-ripgrep | Search project with ripgrep |
| `H` | normal, visual | evil-first-non-blank | First non-whitespace on line |
| `L` | normal, visual | evil-last-non-blank | Last non-whitespace on line |
| `C-o` | normal | evil-jump-backward | Jump back in global jump ring |
| `C-i` | normal, visual | evil-jump-forward | Jump forward in global jump ring |
| `C-a` | normal, insert, visual | my/select-whole-buffer | Select entire buffer |
| `C-u` | normal, insert, visual | evil-scroll-up | Scroll up half screen (animated) |
| `C-d` | normal | evil-scroll-down | Scroll down half screen (animated) |
| `C-f` | normal | evil-scroll-page-down | Page down (animated) |
| `C-b` | normal, insert, visual | consult-buffer | Switch buffer |
| `C-y` | normal | evil-scroll-line-up | Scroll up one line (animated) |

### Tab / Buffer Switching

| Key | Modes | Command | Action |
|-----|-------|---------|--------|
| `C-h` | normal, insert, visual | my/MRU-tabs-backward | Previous MRU tab |
| `C-l` | normal, insert, visual | my/MRU-tabs-forward | Next MRU tab |
| `C-c C-n` | normal, insert, visual | my/MRU-tabs-forward | Next MRU tab |
| `C-<tab>` | any | my/MRU-tabs-forward | Next MRU tab |
| `M-<tab>` | any | my/MRU-tabs-forward | Next MRU tab |
| `C-S-<iso-lefttab>` | any | my/MRU-tabs-backward | Previous MRU tab |

### Dired / Terminal / Misc

| Key | Modes | Command | Action |
|-----|-------|---------|--------|
| `C-e` | normal, insert, visual, motion, emacs | my/dired-from-eat | Toggle dired at eat cwd |
| `C-;` | any | embark-act | Context actions on completion |
| `C-c C-o` | any | consult-recent-file | Recent files |
| `C-c C-i` | any | my/eat-new | Spawn new Eat terminal |
| `C-c C-u` | any | kill-current-buffer | Kill current buffer |

### SPC Leader (press `SPC` in normal/visual mode, `C-SPC` in insert/emacs mode)

#### Files

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC f f` | find-file | Open file |
| `SPC f r` | consult-recent-file | Recent files |
| `SPC f s` | save-buffer | Save buffer |
| `SPC f o` | other-frame | Other frame |

#### Buffers

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC k k` | my/switch-to-other-buffer | Toggle previous buffer |
| `SPC b n` | next-buffer | Next buffer |
| `SPC b p` | previous-buffer | Previous buffer |

#### Windows

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC w v` | evil-window-vsplit | Vertical split |
| `SPC w s` | evil-window-split | Horizontal split |
| `SPC w d` | evil-window-delete | Delete window |
| `SPC w m` | delete-other-windows | Maximize window |
| `SPC w h/j/k/l` | evil-window-move | Navigate windows |

#### Search

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC s s` | consult-line | Search in buffer |
| `SPC s g` | consult-grep | Grep |
| `SPC s r` | consult-ripgrep | Ripgrep in project |

#### Git (Magit)

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC g g` | magit-status | Status |
| `SPC g d` | magit-diff-unstaged | Diff unstaged |
| `SPC g l` | magit-log | Log |
| `SPC g c` | magit-commit | Commit |
| `SPC g p` | magit-push | Push |
| `SPC g f` | magit-fetch | Fetch |
| `SPC g b` | magit-blame | Blame |
| `SPC g [` | diff-hl-previous-hunk | Previous hunk |
| `SPC g ]` | diff-hl-next-hunk | Next hunk |

#### Toggles

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC t l` | display-line-numbers-mode | Toggle line numbers |
| `SPC t w` | whitespace-mode | Toggle whitespace display |
| `SPC t p` | pi-coding-agent-toggle | Toggle Pi AI windows |

#### Project

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC p p` | project-switch-project | Switch project |
| `SPC p f` | project-find-file | Find file in project |
| `SPC p g` | consult-grep | Grep project |
| `SPC p b` | project-switch-to-buffer | Switch project buffer |

#### Pi AI Coding Agent

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC p i` | (prefix) | Pi prefix group |
| `SPC p i i` | pi-coding-agent | Start or focus Pi session |
| `SPC p i f` | my/pi-frame | Pi in dedicated frame |
| `SPC p i t` | pi-coding-agent-toggle | Toggle Pi windows |
| `SPC p i s` | pi-coding-agent-open-session-file | Open session file |
| `SPC p i m` | pi-coding-agent-select-model | Select model |

#### Help / Docs

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC d f` | describe-function | Describe function |
| `SPC d v` | describe-variable | Describe variable |
| `SPC d k` | describe-key | Describe keybinding |
| `SPC d m` | describe-mode | Describe mode |

#### LSP (Eglot)

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC e a` | eglot-code-actions | Code actions |
| `SPC e r` | eglot-rename | Rename symbol |
| `SPC e f` | eglot-format | Format buffer |

#### Org / Notes

| Sequence | Command | Action |
|----------|---------|--------|
| `SPC n c` | org-capture | Capture note/task |
| `SPC n a` | org-agenda | Agenda view |

### Pi Input Buffer (emacs state)

| Key | Command | Action |
|-----|---------|--------|
| `M-RET` / `S-RET` / `C-c C-c` | pi-coding-agent-send | Send prompt |
| `C-c C-s` | pi-coding-agent-queue-steering | Queue steering message |
| `C-c C-k` | pi-coding-agent-abort | Abort streaming |
| `C-c C-p` | pi-coding-agent-menu | Open transient menu |
| `C-c C-r` | pi-coding-agent-resume-session | Resume session |

### Pi Chat Buffer (normal state)

| Key | Command | Action |
|-----|---------|--------|
| `q` | pi-coding-agent-quit | Quit Pi session |

---

## Modules

### init.el

Bootstrap, package management (MELPA, use-package), and sane defaults. Disables GUI elements, backup/auto-save to dedicated directories, quiet bell, follow symlinks, show-paren-mode, global auto-revert, save-place, recentf. Increases GC threshold temporarily for faster startup.

### statuscolumn.el

Custom statuscolumn that replaces built-in line numbers with permanent letter jump labels. Every visible line gets a label (a-z, then punctuation) shown in a 7-character prefix. Running `sc--init` on every post-command-hook keeps labels correct without flicker. Supports jump commands `f` (two-character Avy jump) and `;` (jump to line by label). Shows a scrollbar-thumb icon, evil mark indicators, and continuation line icons.

### MRU-tabs.el

Self-built, zero-dependency tab bar rendered in the header line. Each window has independent tab data (group, MRU order, selection). Buffers are grouped by major mode: Code, Docs, Config, Tools, Eat, and Buffers (catch-all). Tabs are trimmed with overflow indicators when the window is too narrow. Cycling with C-h/C-l or C-<tab>/C-S-<iso-lefttab>.

### jumpring.el

Overrides Evil's per-window jump list with a single global jump ring shared across all windows and buffers. C-o/C-i navigate the same history everywhere. Jumps in non-file buffers (Eat terminals, scratch) are saved by buffer name. Saves and restores the jump ring via savehist.

### neoscroll.el

Smooth animated scrolling for terminal Emacs. Intercepts Evil's native scroll commands and replaces them with animated versions using easing functions. Updates statuscolumn labels after each animation step.

### eat.el

Terminal emulator with shell integration (OSC 7 directory tracking). Uses semi-char input mode. Custom window-adjust-process-window-size-function accounts for the 7-character statuscolumn prefix. Unlimited scrollback.

### doom-modeline.el

Custom mode line with custom segments. Shows line number, buffer name with state icon, and git diff stats (inserts/modifications/deletes). Uses Nerd Font icons.

### diff-hl.el

Change indicators using Nerd Font icons in the left margin. Highlights uncommitted changes with live updating via flydiff. Magit integration refreshes after commits/pushes/pulls.

### keybinds.el

All custom keybindings live here. Defines the SPC leader key (general-create-definer), tab navigation, dired toggle, buffer switching, line motion, Avy jump commands, search overrides, and all SPC-prefixed bindings for files, buffers, windows, search, git, toggles, project, Pi, docs, LSP, and Org.

### consult-buffer.el

Adds an Eat terminal source to consult-buffer. Existing Eat terminals appear as completions; typing a number spawns a new terminal at that index. The default Buffer source is modified to exclude Eat buffers (they appear only in the Eat section). Adds a Previous buffer source at the top.

### embark.el

Context-aware actions via C-; in the minibuffer (embark-act). C-d in consult-buffer kills the selected buffer without confirmation.

### dired.el

Custom listing switches (-alhgG). Uses dired-find-alternate-file (RET reuses the dired buffer). DWIM target directory when copying/moving. ^ and - go up a directory.

### orderless.el

Flexible completion style. Splits input on spaces and matches each component independently (e.g., "fo ba" matches "foobar").

### pi.el

Integration with the Pi coding agent (pi-coding-agent). Provides an Emacs frontend with a Markdown chat buffer and a separate prompt buffer. Custom vertical split layout (input on left, chat on right). Dedicated frame support. Activity-phase minibuffer messages.

### theme.el

Firebat custom theme. Full dark palette with 7-stop gradient from #ff4400 (accent) to #2b2b2b (background). Faces for core UI, syntax highlighting, mode line, Evil search, Vertico/Consult, Magit, Org, Doom Modeline, Eat terminal ANSI colors, Statuscolumn, Diff-hl, Which-key, Avy, Flymake/Eglot, and Dired.

### evil-cursor.el

Terminal cursor changes per Evil state via OSC 12 (color) and DECSCUSR (shape) escape sequences. Normal mode: default. Insert mode: #ff4400 bar. Visual mode: #ff4400 underline.

### panes.el

Window divider glyphs. Replaces vertical border | with + in terminal mode. Sets continuation glyph to center-dot in dim face.

### wl-clipboard.el

Wayland clipboard support for terminal Emacs. Uses wl-copy/wl-paste. Only activates on Wayland sessions.

---

## First-time Setup

1. Packages auto-install via use-package with :ensure t.
2. Install Nerd Font: `M-x nerd-icons-install-fonts RET`
3. For tree-sitter grammars: `M-x treesit-install-language-grammar RET` (Python, Julia, etc.)
4. For Eat shell integration, add to ~/.bashrc:
   ```
   [ -n "$EAT_SHELL_INTEGRATION_DIR" ] && source "$EAT_SHELL_INTEGRATION_DIR/bash"
   ```
5. For Pi CLI: `npm install -g @earendil-works/pi-coding-agent && pi --login`
6. For Wayland clipboard: install wl-clipboard via your package manager.
