;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  dirvish.el — Modern File Manager for Emacs
;;
;;  Dirvish enhances Emacs' built-in Dired mode, providing a polished,
;;  feature-rich file manager with file previews, multiple layouts, VC
;;  integration, and a modern UI. It's inspired by ranger but built as a
;;  proper Emacs-native experience.
;;
;;  Install:  M-x package-install RET dirvish RET
;;
;;  Quick start:
;;    M-x dirvish              → full-frame file manager with preview
;;    M-x dirvish-dwim         → layout-aware version (non-full-frame)
;;    M-x dirvish-dispatch     → cheatsheet / transient menu
;;    M-x dirvish-side         → toggle a file tree sidebar
;;
;;  Keybindings (dirvish-mode-map, inherits dired-mode-map):
;;    q              → quit dirvish session
;;    ?              → dirvish-dispatch (cheatsheet)
;;    h/j/k/l        → Vim-style navigation
;;    i              → toggle preview
;;    g              → revert / refresh
;;    o              → quick-access bookmarks (dirs)
;;    s              → quicksort menu
;;    a              → attribute settings menu
;;    f              → file info menu
;;    v              → VC menu (git)
;;    y              → yank/copy/paste menu
;;    N              → narrow / fd search
;;    TAB            → toggle subtree expand/collapse
;;    M-f            → history forward
;;    M-b            → history back
;;
;;  Extensions (shipped with dirvish, loaded on demand):
;;    dirvish-yank   — two-stage copy/paste (multi-source clipboard)
;;    dirvish-vc     — version control (git) attributes & preview
;;    dirvish-side   — sidebar file tree
;;    dirvish-fd     — async directory listing via `fd`
;;    dirvish-icons  — file icons (nerd-icons / all-the-icons / vscode-icon)
;;    dirvish-ls     — live ls-switch toggling
;;    dirvish-emerge — group files by filter (like ibuffer)
;;    dirvish-peek   — minibuffer file preview for vertico/ivy/icomplete
;;    dirvish-history— session history navigation
;;    dirvish-rsync  — rsync integration
;; =============================================================================

;; ---------------------------------------------------------------------------
;;  Package: dired (base settings)
;; ---------------------------------------------------------------------------

(use-package dired
  :ensure nil  ;; built-in
  :config
  ;; Recommended listing switches for dirvish (use long flags for compat)
  (setq dired-listing-switches
        "-l --almost-all --human-readable --group-directories-first --no-group")

  ;; Allow dired-find-alternate-file (reuse the same dired buffer)
  (put 'dired-find-alternate-file 'disabled nil)

  ;; Mouse drag-and-drop support (Emacs 29+)
  (setq dired-mouse-drag-files t)
  (setq mouse-drag-and-drop-region-cross-program t)

  ;; Move files to trash instead of deleting permanently
  (setq delete-by-moving-to-trash t))

;; ---------------------------------------------------------------------------
;;  Package: dirvish
;; ---------------------------------------------------------------------------

(use-package dirvish
  :ensure t
  :init
  ;; Replace built-in dired with dirvish globally.
  ;; After this, any directory opened in Emacs (C-x d, C-x C-f on a dir, etc.)
  ;; will open in dirvish. Use M-x dired to get plain dired.
  (dirvish-override-dired-mode)

  :custom
  ;; ── Layout ──────────────────────────────────────────────────────
  ;; Layout recipe: (DEPTH MAX-PARENT-WIDTH PREVIEW-WIDTH)
  ;;   DEPTH          — number of parent directory windows (0 = none)
  ;;   MAX-PARENT-WIDTH — max width fraction for each parent window
  ;;   PREVIEW-WIDTH  — width fraction for the preview pane
  ;; Setting depth to 0 gives a clean 2-panel layout: listing | preview.
  (dirvish-default-layout '(0 0.11 0.55))

  ;; ── Attributes ──────────────────────────────────────────────────
  ;; Order matters — these display inline in the file listing.
  (dirvish-attributes
   '(file-size subtree-state collapse))

  ;; ── Mode Line ───────────────────────────────────────────────────
  ;; Show mode line across directory panes only (not global/full-width).
  (dirvish-use-mode-line t)
  ;; Hide the leading bar image in the mode/header line.
  (dirvish-mode-line-bar-image-width 0)
  ;; Mode line segments (left-aligned | right-aligned)
  (dirvish-mode-line-format
   '(:left (sort symlink) :right (omit index)))

  ;; ── Header Line ─────────────────────────────────────────────────
  ;; Show a header line with the current path.
  (dirvish-use-header-line t)
  (dirvish-header-line-format
   '(:left (path) :right (free-space)))
  ;; Path separator icons: [home-icon, root-icon, separator]
  (dirvish-path-separators '(" 󰟒 " " 󰠠 " " 󰁔 "))

  ;; ── File Details ────────────────────────────────────────────────
  ;; Hide file details by default (show only names). Toggle with '('.
  (dirvish-hide-details t)
  ;; Hide the cursor in dirvish buffers (cleaner look).
  (dirvish-hide-cursor t)

  ;; ── Preview ─────────────────────────────────────────────────────
  ;; Preview disabled file extensions.
  (dirvish-preview-disabled-exts '("bin" "exe" "gpg" "elc" "eln" "so"))
  ;; Don't preview files larger than 1 MB (preview them partially).
  (dirvish-preview-large-file-threshold 1048576)
  ;; Max preview buffers to keep open at once.
  (dirvish-preview-buffers-max-count 5)
  ;; Preview dispatchers — methods used for different file types.
  ;; The default dispatchers (dired, fallback) are always active.
  ;; These require external tools (vipsthumbnail, ffmpegthumbnailer, etc).
  (dirvish-preview-dispatchers '(image gif video audio epub pdf archive font))

  ;; ── Async Large Directory Opening ──────────────────────────────
  ;; Use `fd` for directories with > 20000 files (non-blocking).
  ;; Requires `fd` to be installed on your system.
  (dirvish-large-directory-threshold 20000)

  ;; ── Quick Access Entries (SPC o in dirvish) ────────────────────
  ;; These appear in the quick-access menu (bound to `o`).
  (dirvish-quick-access-entries
   '(("h" "~/" "Home")
     ("d" "~/Downloads/" "Downloads")
     ("c" "~/fire_profile/configuration_modules/" "Config Modules")
     ("m" "/mnt/" "Mounts")))

  ;; ── Session Reuse ───────────────────────────────────────────────
  ;; Keep the index buffer around after quitting, for faster re-entry.
  (dirvish-reuse-session 'resume)

  ;; ── Fringe ──────────────────────────────────────────────────────
  ;; Root window left fringe width in pixels.
  (dirvish-window-fringe 2)

  :config
  ;; ── Open at current directory (force) ────────────────────────
  ;; Skip dirvish's session resume so it always opens at the
  ;; buffer's default-directory (e.g., vterm's CWD).
  (defun my/dirvish (&optional path)
    "Open dirvish at PATH or `default-directory'.
Ignores `dirvish-reuse-session' to always respect the current CWD."
    (interactive)
    (let ((dirvish-reuse-session nil))
      (dirvish (or path default-directory))))

  ;; ── Keep dired header lines visible ───────────────────────────
  ;; Dirvish hides the dired header (path + size) via the `invisible'
  ;; property, which also suppresses the statuscolumn line numbers on
  ;; those lines.  We override this: instead of `invisible', use a
  ;; face with tiny `:height' to hide the text visually while keeping
  ;; the lines fully present for the statuscolumn.
  (advice-add 'dirvish--hide-dired-header :after
              (lambda (&rest _)
                (dolist (o (overlays-in (point-min) (point-max)))
                  (when (overlay-get o 'dired-header)
                    (overlay-put o 'invisible nil)
                    (overlay-put o 'face '(:height 0.01 :background unspecified :foreground unspecified))))))

  ;; ── Keybindings ─────────────────────────────────────────────────
  :config
  (define-key dirvish-mode-map "?" 'dirvish-dispatch)
  (define-key dirvish-mode-map "a" 'dirvish-setup-menu)
  (define-key dirvish-mode-map "f" 'dirvish-file-info-menu)
  (define-key dirvish-mode-map "o" 'dirvish-quick-access)
  (define-key dirvish-mode-map "s" 'dirvish-quicksort)
  (define-key dirvish-mode-map "r" 'dirvish-history-jump)
  (define-key dirvish-mode-map "l" 'dirvish-ls-switches-menu)
  (define-key dirvish-mode-map "v" 'dirvish-vc-menu)
  (define-key dirvish-mode-map "y" 'dirvish-yank-menu)
  (define-key dirvish-mode-map "*" 'dirvish-mark-menu)
  (define-key dirvish-mode-map "N" 'dirvish-narrow)
  (define-key dirvish-mode-map "^" 'dirvish-history-last)
  (define-key dirvish-mode-map (kbd "TAB") 'dirvish-subtree-toggle)
  (define-key dirvish-mode-map (kbd "M-f") 'dirvish-history-go-forward)
  (define-key dirvish-mode-map (kbd "M-b") 'dirvish-history-go-backward)
  (define-key dirvish-mode-map (kbd "M-e") 'dirvish-emerge-menu))

(provide 'dirvish)
;; dirvish.el ends here
