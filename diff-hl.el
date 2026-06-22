;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  diff-hl.el — Highlight uncommitted changes using VC
;;
;;  Change indicators displayed in the left margin (via diff-hl's automatic
;;  fallback in terminal mode).  Works alongside the statuscolumn's line numbers
;;  (C engine) and separator overlays (statuscolumn.el).
;;
;;  Integration:
;;    - Dired: highlights changed files in directory listings
;;    - Magit: refreshes indicators after commit/push/pull/etc.
;; =============================================================================

(use-package diff-hl
  :ensure t
  :hook (dired-mode . diff-hl-dired-mode)
  :config
  ;; Enable globally in all file-visiting buffers
  (global-diff-hl-mode 1)

  ;; Update indicators as you type (not just on save)
  (diff-hl-flydiff-mode 1)

  ;; Magit: refresh indicators after any Magit operation
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh))

(provide 'diff-hl)
;; diff-hl.el ends here
