;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  theme.el — firebat Emacs Theme
;;
;;  A custom dark theme with primary background #2b2b2b and accent #ff4400.
;;  Designed for terminal (-nw) use.
;;
;;  Palette gradient (bright → dark):
;;    #ff4400  (255,68,0)    keywords, accent, bump
;;    #da4007  (218,64,7)    builtins, secondary accent
;;    #bf3d0c  (191,61,12)   strings, constants
;;    #913716  (145,55,22)   comments bg, insertion bg
;;    #603120  (96,49,32)    selection, mode-line bg
;;    #462e25  (70,46,37)    line highlight, inactive mode-line
;;    #2b2b2b  (43,43,43)    background
;;
;;  Neutrals:
;;    #d4d4d4  foreground (main text)
;;    #a0a0a0  secondary text
;;    #808080  comments, borders
;; =============================================================================

;; ── Palette variables (for reuse and future customization) ──────

(defvar firebat-bg         "#2b2b2b")
(defvar firebat-fg         "#d4d4d4")
(defvar firebat-fg-alt     "#a0a0a0")
(defvar firebat-comment    "#808080")
(defvar firebat-accent     "#ff4400")
(defvar firebat-accent-alt "#da4007")
(defvar firebat-string     "#bf3d0c")
(defvar firebat-insert-bg  "#913716")
(defvar firebat-region     "#603120")
(defvar firebat-hl         "#462e25")

;; ── Theme definition ────────────────────────────────────────────

(deftheme firebat "A custom dark Emacs theme by fireshark.
Background: #2b2b2b  Accent: #ff4400")

;; ── Faces ───────────────────────────────────────────────────────

(custom-theme-set-faces
 'firebat

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Core UI
 ;; ═══════════════════════════════════════════════════════════════

 `(default ((t (:background ,firebat-bg :foreground ,firebat-fg))))
 `(cursor ((t (:background ,firebat-accent))))
 `(region ((t (:background "#444444" :foreground ,firebat-fg))))
 `(hl-line ((t (:background ,firebat-hl))))
 ;; Paren matching — foreground only (no background, no underline, prevents bleed)
 `(show-paren-match ((t (:foreground ,firebat-accent :extend nil))))
 `(show-paren-match-expression ((t (:foreground ,firebat-accent :extend nil))))
 `(show-paren-mismatch ((t (:background ,firebat-accent :foreground ,firebat-fg))))
 `(minibuffer-prompt ((t (:foreground ,firebat-accent :weight bold))))
 `(vertical-border ((t (:foreground ,firebat-comment))))
 `(line-number ((t (:foreground "#444444"))))
 `(line-number-current ((t (:foreground "#444444"))))
 `(header-line ((t (:background ,firebat-bg :foreground ,firebat-fg-alt))))
 `(highlight ((t (:background ,firebat-hl :foreground ,firebat-accent))))
 `(match ((t (:background ,firebat-insert-bg :foreground ,firebat-fg))))
 `(shadow ((t (:foreground ,firebat-comment))))
 `(link ((t (:foreground ,firebat-accent-alt :underline t))))
 `(link-visited ((t (:foreground ,firebat-string :underline t))))
 `(button ((t (:underline t :foreground ,firebat-accent-alt))))
 `(trailing-whitespace ((t (:background ,firebat-accent))))
 `(error ((t (:foreground ,firebat-accent :weight bold))))
 `(warning ((t (:foreground ,firebat-accent-alt :weight bold))))
 `(success ((t (:foreground ,firebat-string :weight bold))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Syntax Highlighting
 ;; ═══════════════════════════════════════════════════════════════

 `(font-lock-keyword-face ((t (:foreground ,firebat-accent))))
 `(font-lock-function-name-face ((t (:foreground ,firebat-accent-alt))))
 `(font-lock-type-face ((t (:foreground ,firebat-accent :weight bold))))
 `(font-lock-builtin-face ((t (:foreground ,firebat-accent-alt))))
 `(font-lock-string-face ((t (:foreground ,firebat-string))))
 `(font-lock-constant-face ((t (:foreground ,firebat-accent-alt :weight bold))))
 `(font-lock-comment-face ((t (:foreground ,firebat-comment :slant italic))))
 `(font-lock-doc-face ((t (:foreground ,firebat-comment :slant italic))))
 `(font-lock-variable-name-face ((t (:foreground ,firebat-fg))))
 `(font-lock-preprocessor-face ((t (:foreground ,firebat-accent))))
 `(font-lock-negation-char-face ((t (:foreground ,firebat-accent :weight bold))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Mode Line
 ;; ═══════════════════════════════════════════════════════════════

 `(mode-line ((t (:background ,firebat-bg :foreground ,firebat-accent :weight bold))))
 `(mode-line-inactive ((t (:background ,firebat-bg :foreground ,firebat-fg-alt))))
 `(mode-line-highlight ((t (:foreground ,firebat-accent))))
 `(mode-line-emphasis ((t (:foreground ,firebat-accent :weight bold))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Evil
 ;; ═══════════════════════════════════════════════════════════════

 `(evil-ex-lazy-highlight ((t (:background ,firebat-region :foreground ,firebat-accent))))
 `(evil-search-highlight-persist-highlight ((t (:background ,firebat-region))))
 `(evil-ex-substitute-matches ((t (:background ,firebat-insert-bg :foreground ,firebat-fg))))
 `(evil-ex-substitute-replacement ((t (:foreground ,firebat-accent :weight bold))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Vertico / Corfu (minibuffer & completion)
 ;; ═══════════════════════════════════════════════════════════════

 `(vertico-current ((t (:background ,firebat-hl :foreground ,firebat-fg))))
 `(vertico-group-title ((t (:foreground ,firebat-comment :weight bold))))
 `(corfu-current ((t (:background ,firebat-hl :foreground ,firebat-fg))))
 `(corfu-bar ((t (:background ,firebat-region))))
 `(corfu-border ((t (:background ,firebat-hl))))
 `(corfu-default ((t (:background ,firebat-bg :foreground ,firebat-fg))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Consult
 ;; ═══════════════════════════════════════════════════════════════

 `(consult-preview-line ((t (:background ,firebat-hl))))
 `(consult-preview-match ((t (:foreground ,firebat-accent :weight bold))))
 `(consult-file ((t (:foreground ,firebat-fg-alt))))
 `(consult-bookmark ((t (:foreground ,firebat-accent-alt))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Magit
 ;; ═══════════════════════════════════════════════════════════════

 `(magit-section-heading ((t (:foreground ,firebat-accent :weight bold))))
 `(magit-section-highlight ((t (:background ,firebat-hl))))
 `(magit-branch-current ((t (:foreground ,firebat-accent :weight bold))))
 `(magit-branch-local ((t (:foreground ,firebat-accent-alt))))
 `(magit-branch-remote ((t (:foreground ,firebat-string))))
 `(magit-diff-added ((t (:foreground ,firebat-string :background ,firebat-hl))))
 `(magit-diff-removed ((t (:foreground ,firebat-insert-bg :background ,firebat-hl))))
 `(magit-diff-hunk-heading ((t (:background ,firebat-hl :foreground ,firebat-fg-alt))))
 `(magit-diff-hunk-heading-highlight ((t (:background ,firebat-region :foreground ,firebat-fg))))
 `(magit-tag ((t (:foreground ,firebat-comment))))
 `(magit-hash ((t (:foreground ,firebat-comment))))
 `(magit-log-author ((t (:foreground ,firebat-accent-alt))))
 `(magit-log-date ((t (:foreground ,firebat-comment))))
 `(magit-log-graph ((t (:foreground ,firebat-fg-alt))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Org Mode
 ;; ═══════════════════════════════════════════════════════════════

 `(org-level-1 ((t (:foreground ,firebat-accent :weight bold :height 1.2))))
 `(org-level-2 ((t (:foreground ,firebat-accent-alt :height 1.1))))
 `(org-level-3 ((t (:foreground ,firebat-string))))
 `(org-level-4 ((t (:foreground ,firebat-fg-alt))))
 `(org-level-5 ((t (:foreground ,firebat-comment))))
 `(org-todo ((t (:foreground ,firebat-accent :weight bold))))
 `(org-done ((t (:foreground ,firebat-comment))))
 `(org-headline-done ((t (:foreground ,firebat-comment))))
 `(org-date ((t (:foreground ,firebat-accent-alt))))
 `(org-link ((t (:foreground ,firebat-accent-alt :underline t))))
 `(org-block ((t (:background ,firebat-hl))))
 `(org-block-begin-line ((t (:background ,firebat-hl :foreground ,firebat-comment))))
 `(org-block-end-line ((t (:background ,firebat-hl :foreground ,firebat-comment))))
 `(org-code ((t (:foreground ,firebat-string))))
 `(org-table ((t (:foreground ,firebat-fg-alt))))
 `(org-priority ((t (:foreground ,firebat-accent :weight bold))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Doom Modeline
 ;; ═══════════════════════════════════════════════════════════════

 `(doom-modeline-buffer-modified ((t (:foreground ,firebat-accent))))
 `(doom-modeline-buffer-major-mode ((t (:foreground ,firebat-accent-alt :weight bold))))
 `(doom-modeline-bar ((t (:background ,firebat-accent))))
 `(doom-modeline-project-dir ((t (:foreground ,firebat-fg-alt))))
 `(doom-modeline-buffer-path ((t (:foreground ,firebat-fg-alt))))
 `(doom-modeline-panel ((t (:background ,firebat-region :foreground ,firebat-fg))))



 ;; ═══════════════════════════════════════════════════════════════
 ;;  Terminal (term-mode)
 ;; ═══════════════════════════════════════════════════════════════

 `(term ((t (:background ,firebat-bg :foreground ,firebat-fg))))
 `(term-color-black   ((t (:foreground ,firebat-bg :background ,firebat-bg))))
 `(term-color-red     ((t (:foreground ,firebat-accent     :background ,firebat-accent))))
 `(term-color-green   ((t (:foreground ,firebat-string     :background ,firebat-string))))
 `(term-color-yellow  ((t (:foreground ,firebat-accent-alt :background ,firebat-accent-alt))))
 `(term-color-blue    ((t (:foreground ,firebat-insert-bg  :background ,firebat-insert-bg))))
 `(term-color-magenta ((t (:foreground ,firebat-region     :background ,firebat-region))))
 `(term-color-cyan    ((t (:foreground ,firebat-comment    :background ,firebat-comment))))
 `(term-color-white   ((t (:foreground ,firebat-fg        :background ,firebat-fg))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Statuscolumn (visual line numbers)
 ;; ═══════════════════════════════════════════════════════════════

 `(sc-line-number ((t (:foreground "#444444"))))
 `(sc-separator ((t (:foreground "#444444"))))
 `(sc-bump ((t (:foreground ,firebat-accent :weight bold))))
 `(sc-label-face ((t (:foreground "#444444" :background ,firebat-bg))))
 `(sc-current-face ((t (:foreground ,firebat-accent :background ,firebat-bg))))
 `(sc-sep ((t (:foreground "#444444"))))
 `(sc-wrap-icon ((t (:foreground ,firebat-accent :background ,firebat-bg))))
 `(sc-wrap-icon-dim ((t (:foreground "#444444" :background ,firebat-bg))))
 ;; ═══════════════════════════════════════════════════════════════
 ;;  Diff-hl (left margin icons)
 ;; ═══════════════════════════════════════════════════════════════

 `(diff-hl-margin-insert ((t (:foreground ,firebat-accent :background ,firebat-bg))))
 `(diff-hl-margin-delete ((t (:foreground ,firebat-accent :background ,firebat-bg))))
 `(diff-hl-margin-change ((t (:foreground ,firebat-accent :background ,firebat-bg))))
 `(diff-hl-margin-unknown ((t (:foreground ,firebat-accent :background ,firebat-bg))))
 `(diff-hl-margin-ignored ((t (:foreground ,firebat-comment :background ,firebat-bg))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Centaur Tabs
 ;; ═══════════════════════════════════════════════════════════════

 `(centaur-tabs-default ((t (:background ,firebat-bg :foreground ,firebat-bg))))
 `(centaur-tabs-selected ((t (:background ,firebat-accent :foreground ,firebat-bg :weight bold))))
 `(centaur-tabs-unselected ((t (:background ,firebat-bg :foreground ,firebat-accent))))
 `(centaur-tabs-selected-modified ((t (:background ,firebat-accent :foreground ,firebat-bg :weight bold))))
 `(centaur-tabs-unselected-modified ((t (:background ,firebat-bg :foreground ,firebat-accent))))
 `(centaur-tabs-active-bar-face ((t (:background ,firebat-accent))))
 `(centaur-tabs-close-selected ((t (:inherit centaur-tabs-selected))))
 `(centaur-tabs-close-unselected ((t (:inherit centaur-tabs-unselected))))
 `(centaur-tabs-modified-marker-selected ((t (:foreground ,firebat-accent))))
 `(centaur-tabs-modified-marker-unselected ((t (:foreground ,firebat-fg-alt))))
 `(my/centaur-tabs-group-face ((t (:foreground ,firebat-accent :background ,firebat-bg :weight bold))))
 `(my/centaur-tabs-group-icon ((t (:background ,firebat-accent :foreground ,firebat-bg :weight bold))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Which-key
 ;; ═══════════════════════════════════════════════════════════════

 `(which-key-key-face ((t (:foreground ,firebat-accent))))
 `(which-key-group-description-face ((t (:foreground ,firebat-accent-alt))))
 `(which-key-command-description-face ((t (:foreground ,firebat-fg))))
 `(which-key-separator-face ((t (:foreground ,firebat-comment))))
 `(which-key-note-face ((t (:foreground ,firebat-comment))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Avy
 ;; ═══════════════════════════════════════════════════════════════

 `(avy-lead-face ((t (:foreground "#ff4400" :background "#2b2b2b" :weight bold))))
 `(avy-lead-face-0 ((t (:foreground "#ff4400" :background "#2b2b2b"))))
 `(avy-lead-face-1 ((t (:foreground "#ff4400" :background "#2b2b2b"))))
 `(avy-lead-face-2 ((t (:foreground "#ff4400" :background "#2b2b2b"))))
 `(avy-background-face ((t (:foreground ,firebat-comment))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Eglot / Flymake (LSP diagnostics)
 ;; ═══════════════════════════════════════════════════════════════

 `(flymake-error ((t (:underline (:style wave :color ,firebat-accent)))))
 `(flymake-warning ((t (:underline (:style wave :color ,firebat-accent-alt)))))
 `(flymake-note ((t (:underline (:style wave :color ,firebat-comment)))))
 `(eglot-mode-line ((t (:foreground ,firebat-accent-alt))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Rainbow Delimiters
 ;; ═══════════════════════════════════════════════════════════════

 `(rainbow-delimiters-depth-1-face ((t (:foreground ,firebat-accent))))
 `(rainbow-delimiters-depth-2-face ((t (:foreground ,firebat-accent-alt))))
 `(rainbow-delimiters-depth-3-face ((t (:foreground ,firebat-string))))
 `(rainbow-delimiters-depth-4-face ((t (:foreground ,firebat-insert-bg))))
 `(rainbow-delimiters-depth-5-face ((t (:foreground ,firebat-region))))
 `(rainbow-delimiters-depth-6-face ((t (:foreground ,firebat-comment))))
 `(rainbow-delimiters-depth-7-face ((t (:foreground ,firebat-accent))))
 `(rainbow-delimiters-depth-8-face ((t (:foreground ,firebat-accent-alt))))
 `(rainbow-delimiters-unmatched-face ((t (:foreground ,firebat-accent :weight bold :underline t))))

 ;; ═══════════════════════════════════════════════════════════════
 ;;  Dired / Dirvish
 ;; ═══════════════════════════════════════════════════════════════

 `(dired-directory ((t (:foreground ,firebat-accent :weight bold))))
 `(dired-header ((t (:foreground ,firebat-accent-alt :weight bold))))
 `(dired-flagged ((t (:foreground ,firebat-accent :weight bold))))
 `(dired-mark ((t (:foreground ,firebat-accent))))
 `(dired-marked ((t (:foreground ,firebat-accent-alt))))
 `(dired-symlink ((t (:foreground ,firebat-string))))
 `(dired-broken-symlink ((t (:foreground ,firebat-accent))))
 `(dired-ignored ((t (:foreground ,firebat-comment))))
 ;; Dirvish faces removed — dirvish has been uninstalled.
)

;; ── Provide ─────────────────────────────────────────────────────

(provide-theme 'firebat)

(provide 'theme)
;; theme.el ends here
