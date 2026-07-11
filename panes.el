;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  panes.el — Window Divider & Pane Configuration
;;
;;  Renders unique vertical-border characters based on the selected window's
;;  position among its horizontal siblings.  Updated instantly on keyboard
;;  window transitions (C-w w, C-x o, etc.).
;;
;;  Rules
;;  ─────
;;  If selected window is:
;;    leftmost  (right only)  → its right border shows ┤, all others show │
;;    middle    (left+right)  → its left neighbor shows ├,
;;                              the selected window shows ┤,
;;                              all others show │
;;    rightmost (left only)   → its left neighbor shows ├,
;;                              all others show │
;;
;;  In terminal mode, the wrap glyph is also customized.
;; =============================================================================

(defface panes-border-face
  '((t (:foreground "#ff4400" :background "#2b2b2b")))
  "Face for the window divider vertical-border character (╎).")

;; ── Per-window vertical border glyphs ──────────────────────

(defun panes-update-window-borders (&optional frame)
  "Update vertical-border characters based on the selected window's position."
  (setq frame (or frame (selected-frame)))
  (let* ((current          (selected-window))
         (left-of-current  (window-in-direction 'left current frame))
         (windows          (window-list frame 0)))
    (dolist (win windows)
      (let* ((has-right (window-in-direction 'right win frame))
             (char     (cond
                        ;; No right border column to set
                        ((not has-right)          nil)
                        ;; Selected window always gets ┤
                        ((eq win current)         ?╎)
                        ;; Window immediately left of selected gets ├
                        ((and left-of-current
                              (eq win left-of-current)) ?╎)
                        ;; Everything else gets │
                        (t                        ?╎))))
        (when char
          (let* ((table (or (window-display-table win)
                           (set-window-display-table win (make-display-table))))
                 (wrap (and standard-display-table
                            (display-table-slot standard-display-table 'wrap))))
            (set-display-table-slot table 'vertical-border
                                    (make-glyph-code char 'panes-border-face))
            ;; Window display tables fully shadow buffer/standard tables,
            ;; so carry over the wrap glyph to avoid falling back to
            ;; Emacs' default \ wrap indicator.
            (when wrap
              (set-display-table-slot table 'wrap wrap))))))))

;; ── Auto-update hooks ──────────────────────────────────────

(defun panes--window-selection-change (frame)
  "Refresh borders when the selected window changes on FRAME."
  (panes-update-window-borders frame))

(defun panes--window-state-change (&optional frame)
  "Refresh borders when windows are added or removed on FRAME."
  (panes-update-window-borders frame))

;; Update on every keyboard-driven window transition
(add-hook 'window-selection-change-functions #'panes--window-selection-change)

;; Update when windows are split, deleted, or resized
(add-hook 'window-state-change-hook #'panes--window-state-change)

;; ── Interactive command ────────────────────────────────────
(defun panes-refresh ()
  "Refresh vertical-border characters for all windows."
  (interactive)
  (panes-update-window-borders))

;; ── Wrap glyph (GUI + terminal) ───────────────────────────
;; Standard display table (global fallback)
(let ((table (or standard-display-table
                 (setq standard-display-table (make-display-table)))))
  (set-display-table-slot table 'wrap (make-glyph-code ?\s 'shadow)))

;; Buffer-local display tables in terminal emulators that
;; shadow the standard display table.
(dolist (hook '(eat-mode-hook vterm-mode-hook))
  (add-hook hook
            (lambda ()
              (when-let ((table (or buffer-display-table
                                    (setq buffer-display-table
                                          (make-display-table)))))
                (set-display-table-slot table 'wrap
                                        (make-glyph-code ?\s 'shadow))))))

;; Initial border layout
(panes-update-window-borders)

(provide 'panes)
;; panes.el ends here
