;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  diff-hl.el — Highlight uncommitted changes using VC
;;
;;  Change indicators displayed in the left margin using Nerd Font icons.
;;
;;  Integration:
;;    - Dired: highlights changed files in directory listings
;;    - Magit: refreshes indicators after commit/push/pull/etc.
;; =============================================================================

(use-package diff-hl
  :ensure t
  :hook (dired-mode . diff-hl-dired-mode)
  :config
  ;; Left margin display with Nerd Font icons
  (setq diff-hl-margin-symbols-alist
        '((insert . " 󰐗") (delete . " 󰅙") (change . " 󰆗")
          (unknown . "󰋗") (ignored . " 󰍶") (reference . " 󱆮")))

  ;; Enable globally in all file-visiting buffers
  (global-diff-hl-mode 1)

  ;; Increase margin width to accommodate the leading-space icons
  ;; This must be set BEFORE diff-hl-margin-mode so the margin is wide enough.
  (setq-default left-margin-width 2)
  (setq left-margin-width 2)

  ;; Margin display (must come after global-diff-hl-mode to ensure hooks exist)
  (diff-hl-margin-mode 1)

  ;; Apply the wider margin to all existing windows
  (dolist (win (window-list))
    (set-window-margins win 2 (cdr (window-margins win))))

  ;; Update indicators as you type (not just on save)
  (diff-hl-flydiff-mode 1)

  ;; Magit: refresh indicators after any Magit operation
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh))

(provide 'diff-hl)
;; diff-hl.el ends here
