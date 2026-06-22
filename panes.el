;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  panes.el — Window Divider & Pane Configuration
;;
;;  Customizes the appearance of window dividers for vertical splits.
;;  In terminal mode, the vertical border uses a display table slot
;;  to replace the default "|" character with a custom one.
;; =============================================================================

;; ── Continuation glyph (wrapped lines) ─────────────────────
;; When a line wraps, Emacs shows a glyph at the break point.
;; Default is \ — replace with · (U+00B7) in a dim face.
(unless (display-graphic-p)
  (let ((table (or standard-display-table
                   (setq standard-display-table (make-display-table)))))
    (set-display-table-slot table 'vertical-border (make-glyph-code ?┼))
    (set-display-table-slot table 'wrap (make-glyph-code ?· 'shadow)))

  ;; Re-apply to buffer-local display tables (terminal emulators
  ;; set their own, shadowing the standard display table).
  (dolist (hook '(eat-mode-hook vterm-mode-hook))
    (add-hook hook
              (lambda ()
                (when-let ((table (or buffer-display-table
                                      (setq buffer-display-table
                                            (make-display-table)))))
                  (set-display-table-slot table 'vertical-border
                                          (make-glyph-code ?┼))
                  (set-display-table-slot table 'wrap
                                          (make-glyph-code ?· 'shadow)))))))

(provide 'panes)
;; panes.el ends here
