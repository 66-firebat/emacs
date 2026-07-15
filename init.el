;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  Emacs Configuration — Minimal + Evil + Doom Modeline
;;  Run with: emacs -nw
;;
;;  A clean, minimal Emacs config built on:
;;      - Evil mode (vim everywhere via evil-collection)
;;      - Doom Modeline with Nerd Font icons
;;      - Vertico + Consult + Marginalia (modern minibuffer)
;;      - Magit (git), Eglot (LSP), Org mode
;;      - Firebat theme (#2b2b2b bg, #ff4400 accent)
;; =============================================================================

;; ---------------------------------------------------------------------------
;;  1.  Package Management
;; ---------------------------------------------------------------------------

(require 'package)

;; Add MELPA — the main Emacs package repository
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

;; Initialize the package system
(package-initialize)

;; Auto-install `use-package` if it's not already present.
;; use-package is built into Emacs 29+, but this ensures it's available
;; even on older versions or minimal installations.
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

;; Always install packages declared with `:ensure t` without prompting
(setq use-package-always-ensure t)

;; ---------------------------------------------------------------------------
;;  2.  Sane Defaults — Clean Terminal UI
;; ---------------------------------------------------------------------------

;; Disable GUI elements — these do nothing in -nw mode but don't hurt
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)
(setq gc-cons-threshold 100000000) ; Increase to ~100MB during heavy tasks
; Disable Line Wrapping on Shell Buffers: Force Emacs to stop trying to wrap long incoming text streams dynamically
(add-hook 'shell-mode-hook (lambda () (setq truncate-lines t)))

;; A friendlier scratch buffer message
(setq initial-scratch-message ";; Welcome to Emacs + Evil\n")

;; Shorter prompts — type "y" instead of "yes"
(defalias 'yes-or-no-p 'y-or-n-p)

;; Keep backup files out of your working directory
(setq backup-directory-alist '(("." . "~/.emacs.d/backups"))
      backup-by-copying t)
(make-directory "~/.emacs.d/backups" t)

;; Auto-save files in a dedicated directory too
(setq auto-save-file-name-transforms '((".*" "~/.emacs.d/auto-save/" t)))
(make-directory "~/.emacs.d/auto-save" t)

;; Silence the bell — no beeping
(setq ring-bell-function 'ignore)

;; Scroll behavior — never recenter cursor when scrolling past window edges.
;; With scroll-conservatively > 100, Emacs scrolls just enough to bring
;; point into view at the top/bottom of the window, without centering it.
;; This gives the equivalent of Vim's scrolloff=0.
(setq scroll-conservatively 101)
(setq scroll-margin 0)

;; Follow symlinks when opening files (useful on NixOS / home-manager)
(setq find-file-visit-truename t)

;; Show matching parentheses
(show-paren-mode 1)

;; Delete trailing whitespace before saving every file
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; Revert buffers automatically when the file changes on disk
(global-auto-revert-mode 1)

;; Remember cursor position when revisiting files
(save-place-mode 1)

;; Recent files list
(recentf-mode 1)
(setq recentf-max-saved-items 100)
(add-hook 'find-file-hook 'recentf-track-opened-file)

;; Don't show the Emacs startup screen
(setq inhibit-startup-screen t)

;; Speed up startup by temporarily increasing the GC threshold.
;; Reset it after startup is complete.
(setq gc-cons-threshold 100000000)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold 800000)))

;; ---------------------------------------------------------------------------
;;  3.  Evil Mode — Vim Emulation Everywhere
;; ---------------------------------------------------------------------------

;; `evil` is the core vim emulation layer for Emacs.
;; With `evil-collection`, it provides vim keybindings for nearly every
;; built-in and third-party mode.
(use-package evil
  :demand t                   ;; Load immediately — not lazy
  :init
  ;; CRITICAL: Tell evil-collection to handle keybinding setup.
  ;; Without this, evil and evil-collection will conflict.
  (setq evil-want-keybinding nil)

  ;; Vim-like behaviour tweaks
  (setq evil-want-C-i-jump t)         ;; C-i / TAB forward in jump list
  (setq evil-want-Y-yank-to-eol t)     ;; Y yanks to end of line (like Vim)
  (setq evil-want-fine-undo t)         ;; Granular undo per insertion
  (setq evil-move-beyond-eol t)        ;; Like Vim's virtualedit=all
  (setq evil-move-cursor-back nil)     ;; Don't snap cursor off blank chars
  (setq evil-cross-lines t)            ;; Allow h/l across line boundaries
  (setq evil-split-window-below t)     ;; :split opens below
  (setq evil-vsplit-window-right t)    ;; :vsplit opens to the right
  (setq evil-undo-system 'undo-redo)   ;; Modern undo-redo (Emacs 28+)
  :config
  (evil-mode 1)

  ;; Start certain modes in Emacs state (free Emacs keybindings).
  ;; These are modes where vim normal mode would interfere:
  (dolist (mode '(help-mode
                  profiler-report-mode
                  term-mode))
    (evil-set-initial-state mode 'emacs)))

;; Evil Collection — vim keybindings for EVERY mode.
;; This is what makes things like M-x, magit, dired, org, etc.
;; all respond to vim keys. Without it, only evil-mode buffers
;; would have vim bindings.
(use-package evil-collection
  :ensure t
  :after evil
  :demand t
  :config
  (evil-collection-init))

;; ---------------------------------------------------------------------------
;;  3b.  Evil Cursor — Per-state terminal cursor colors
;; ---------------------------------------------------------------------------

(let ((real-dir (file-name-directory
                 (file-truename (or load-file-name buffer-file-name)))))
  (load (expand-file-name "evil-cursor.el" real-dir)))

;; ---------------------------------------------------------------------------
;;  3c.  Kitty Keyboard Protocol — Proper key encoding in terminal
;; ---------------------------------------------------------------------------

;; The kkp package decodes CSI-u escape sequences (used by Ghostty, kitty,
;; WezTerm, etc.) into proper Emacs key events.  This makes keys like C-i
;; distinguishable from TAB, among many others.
(use-package kkp
  :ensure t
  :demand t
  :config
  (global-kkp-mode 1)

  ;; When running as daemon + emacsclient, KKP might not initialize properly
  ;; because the terminal doesn't exist yet at load time. Force re-init when
  ;; a new terminal frame appears.
  (defun my/kkp-ensure-active ()
    "Ensure KKP is active in the current terminal.
Re-runs setup if the terminal was visited but KKP isn't active."
    (when (and (boundp 'kkp--active-terminal-list)
               (boundp 'kkp--setup-visited-terminal-list)
               (not (display-graphic-p)))
      (let ((terminal (frame-terminal (selected-frame))))
        (when (and (terminal-live-p terminal)
                   (not (member terminal kkp--active-terminal-list))
                   (member terminal kkp--setup-visited-terminal-list))
          ;; Terminal was visited but setup never completed — retry
          (setq kkp--setup-visited-terminal-list
                (delete terminal kkp--setup-visited-terminal-list))
          (kkp-enable-in-terminal terminal)))))

  ;; Run on every frame switch to catch the daemon->client transition
  (add-function :after after-focus-change-function
                (lambda (&rest _) (my/kkp-ensure-active)))

  ;; Also run after server-visit-hook (when emacsclient connects)
  (with-eval-after-load 'server
    (add-hook 'server-visit-hook #'my/kkp-ensure-active))

  ;; Interactive restart command
  (defun my/kkp-restart ()
    "Restart KKP in the current terminal."
    (interactive)
    (let ((terminal (frame-terminal (selected-frame))))
      (when (boundp 'kkp--active-terminal-list)
        ;; Tear down if active
        (when (member terminal kkp--active-terminal-list)
          (kkp--terminal-teardown terminal))
        ;; Reset visited status so focus-change re-enables
        (when (boundp 'kkp--setup-visited-terminal-list)
          (setq kkp--setup-visited-terminal-list
                (delete terminal kkp--setup-visited-terminal-list)))
        (kkp-enable-in-terminal terminal)
        (message "KKP restart triggered — check *Messages* for [KKP] logs")))))

;; ---------------------------------------------------------------------------
;;  4.  Leader Key — SPC (Space) is our leader
;; ---------------------------------------------------------------------------

;; `general` provides a clean way to define keybindings, including
;; leader-key prefixes. It replaces Emacs' more verbose `define-key`.
(use-package general
  :ensure t
  :demand t
  :config
  ;; Define the leader key:
  ;;   - SPC in normal/visual/motion states (vim modes)
  ;;   - C-SPC in insert/emacs states (to avoid conflicting with SPC
  ;;     insertion in insert mode)
  (general-create-definer leader
    :states '(normal visual motion)
    :prefix "SPC"
    :global-prefix "C-SPC"
    :keymaps 'override)

  ;; All keybindings have been moved to keybinds.el
  )

;; ---------------------------------------------------------------------------
;;  5.  Which-Key — See available keybindings as you type
;; ---------------------------------------------------------------------------

;; Shows a popup of possible keybindings after you press the leader key
;; (or any prefix). Essential for discovering what's available.
(use-package which-key
  :demand t
  :config
  (which-key-mode 1)
  (setq which-key-idle-delay 0.5))  ;; Show after 0.5s of inactivity

;; ---------------------------------------------------------------------------
;;  6.  Doom Modeline — A clean, informative mode line with Nerd Font icons
;; ---------------------------------------------------------------------------

(let ((real-dir (file-name-directory
                 (file-truename (or load-file-name buffer-file-name)))))
  (load (expand-file-name "doom-modeline.el" real-dir)))

;; ---------------------------------------------------------------------------
;;  7.  Modern Minibuffer Completion — Vertico + Consult + Marginalia
;; ---------------------------------------------------------------------------

;; Vertico provides a vertical completion UI for the minibuffer.
;; This affects M-x, C-x C-f, C-x b, and any completing-read prompt.
;; It's lightweight and works with the default completion system.
(use-package vertico
  :demand t
  :config
  (vertico-mode 1)
  (setq vertico-cycle t))  ;; Wrap around at top/bottom of list

;; Marginalia adds helpful annotations to completion candidates.
;; For example, it shows "(command)" next to M-x results, file sizes
;; next to find-file results, etc.
(use-package marginalia
  :demand t
  :config
  (marginalia-mode 1))

;; Consult provides powerful search and navigation commands that
;; integrate with Vertico: consult-line, consult-grep, consult-buffer, etc.
(use-package consult
  :demand t
  :bind (("M-y" . consult-yank-pop)
         ("C-x b" . consult-buffer)
         ("M-s g" . consult-grep)
         ("M-s l" . consult-line)
         ("M-s r" . consult-ripgrep)
         ("M-s f" . consult-find))
  :config
  (setq consult-narrow-key "<"))

;; ---------------------------------------------------------------------------
;;  8.  Git — Magit
;; ---------------------------------------------------------------------------

;; Magit is the premier git interface for Emacs.
;; With evil-collection loaded, it uses vim keybindings too.
(use-package magit
  :defer t
  :config
  (setq magit-display-buffer-function
        'magit-display-buffer-fullframe-status-v1))

;; ---------------------------------------------------------------------------
;;  9.  Language Support — Julia & Python
;; ---------------------------------------------------------------------------

;; --- Python ---
(use-package python
  :defer t
  :mode ("\\.py\\'" . python-mode)
  :config
  (setq python-indent-offset 4)
  ;; Enable LSP via Eglot
  (add-hook 'python-mode-hook 'eglot-ensure))

;; --- Tree-sitter — Modern syntax highlighting ---
;; Tree-sitter is built into Emacs 30 (C core, no package needed).
;; To install grammars, run `M-x treesit-install-language-grammar`.
(use-package treesit
  :ensure nil          ;; Built into Emacs 30, not on MELPA
  :demand t
  :config
  ;; Maximum font-lock detail (1-4)
  (setq treesit-font-lock-level 4)
  ;; Enable tree-sitter modes when grammars are available
  (add-hook 'python-mode-hook (lambda ()
                                (when (treesit-ready-p 'python)
                                  (python-ts-mode))))
  )

;; --- Common LSP settings (Eglot) ---
(use-package eglot
  :defer t
  :config
  (setq eglot-autoshutdown t)         ;; Shut down LSP when last buffer closes
  (setq eglot-events-buffer-size 0)   ;; Disable LSP event log (speed)
  (setq eglot-sync-connect nil)       ;; Connect asynchronously
)

;; ---------------------------------------------------------------------------
;;  10.  Org Mode — Notes, TODOs, Agenda
;; ---------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  ;; Org directory — where your org files live
  (setq org-directory "~/org")
  (make-directory org-directory t)

  ;; Default org file for quick capture
  (setq org-default-notes-file (concat org-directory "/notes.org"))

  ;; Agenda files
  (setq org-agenda-files (list org-directory))

  ;; TODO keywords — configurable workflow states
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "IN-PROGRESS(i)" "WAITING(w@/!)"
                    "| DONE(d)" "CANCELLED(c@)")))

  ;; Terminal-friendly prettiness
  (setq org-ellipsis " ▶")
  (setq org-hide-emphasis-markers t)
  (setq org-pretty-entities t)

  ;; Capture templates — quick notes with SPC n c (once we bind it)
  (setq org-capture-templates
        '(("t" "Task" entry (file+headline org-default-notes-file "Tasks")
           "* TODO %?\n  %i\n  %a")
          ("n" "Note" entry (file+headline org-default-notes-file "Notes")
           "* %?\n  %i\n  %U")
          ("j" "Journal" entry (file+datetree (concat org-directory "/journal.org"))
           "* %?\nEntered on %U\n")))

  ;; Indent org files for easier reading
  (add-hook 'org-mode-hook 'org-indent-mode)

  ;; Evil keybindings for org-mode are handled by evil-collection,
  ;; so no extra setup needed here.
  )

;; ---------------------------------------------------------------------------
;;  11.  Avy — Jump to any visible character on screen
;; ---------------------------------------------------------------------------

;; Avy lets you jump to any visible character by typing a short code.
;; Think of it like Vim's EasyMotion or sneak.vim.
(use-package avy
  :defer t
  :config
  (setq avy-background t)          ;; Dim the rest of the buffer
  (setq avy-style 'at-full)        ;; Show full candidate text
  (setq avy-all-windows t)         ;; All windows on current frame
  (setq avy-timeout-seconds 0.3))  ;; Timer for avy-goto-char-timer

;; ---------------------------------------------------------------------------
;;  12.  Project Management
;; ---------------------------------------------------------------------------

(use-package project
  :defer t
  :config
  (setq project-vc-extra-root-markers '(".git" ".project" ".jlpm")))

;; ---------------------------------------------------------------------------
;;  13.  Custom Module Loading — Moved here to prevent void function errors
;; ---------------------------------------------------------------------------

(defvar my/init-dir
  (file-name-directory (file-truename (or load-file-name buffer-file-name)))
  "Directory containing this init.el and all config modules.")

(defun my/load-module (name)
  "Load a configuration module from the config directory."
  (load (expand-file-name name my/init-dir)))

;; ── Core UI ─────────────────────────────────────────────────────────────────
(my/load-module "statuscolumn.el")   ;; Statuscolumn with letter jump labels
(global-sc-mode 1)                    ;; Activate globally
(my/load-module "neoscroll.el")      ;; Smooth animated scrolling
(my/load-module "panes.el")          ;; Window divider & wrap glyph
(my/load-module "MRU-tabs.el")        ;; MRU-based tab bar

;; ── Navigation ──────────────────────────────────────────────────────────────
(my/load-module "jumpring.el")       ;; Global C-o/C-i jump ring

;; ── Terminal ────────────────────────────────────────────────────────────────
(my/load-module "eat.el")            ;; Terminal emulator inside Emacs
(my/load-module "grease/eat-grease.el") ;; Eat <-> Grease integration

;; ── Editing ─────────────────────────────────────────────────────────────────
(my/load-module "embark.el")         ;; Context-aware actions
(my/load-module "dired.el")          ;; Dired customizations
(my/load-module "diff-hl.el")        ;; Highlight uncommitted changes

;; ── File Manager ────────────────────────────────────────────────
(setq grease-show-hidden t)          ;; Show hidden files (dotfiles) in grease
(my/load-module "grease/grease.el")       ;; Oil.nvim-style writable file manager

;; ── Orderless Completion Addons ─────────────────────────────────────────────
(my/load-module "orderless.el")      ;; Flexible completion style
(my/load-module "consult-buffer.el") ;; Custom sources loaded after consult

;; ── Languages ───────────────────────────────────────────────────────────────
(my/load-module "julia.el")          ;; Julia tree-sitter mode

;; ── Misc ────────────────────────────────────────────────────────────────────
(my/load-module "pi.el")             ;; AI coding agent frontend
(my/load-module "wl-clipboard.el")   ;; Wayland clipboard integration
(my/load-module "theme.el")          ;; Firebat theme
(my/load-module "emacs-zoxide/zoxide.el")  ;; Zoxide directory jumper
(enable-theme 'firebat)

;; ── Keybinds — depends on evil, general, which-key being loaded first ──────
(my/load-module "keybinds.el")

;; ---------------------------------------------------------------------------
;;  14.  Final Touches
;; ---------------------------------------------------------------------------

;; Save the custom-set-variables block to a separate file so we don't
;; pollute init.el with package customizations.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(provide 'init)
;; init.el ends here
