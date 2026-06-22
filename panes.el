;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  panes.el — Window Divider & Pane Configuration
;;
;;  Customizes the appearance of window dividers for vertical splits.
;;  In terminal mode, the vertical border uses a display table slot
;;  to replace the default "|" character with a custom one.
;; =============================================================================

;; ── Vertical border character ───────────────────────────────
;; In terminal (-nw) mode, Emacs draws vertical window borders
;; using a single character from the display table. The default
;; is "|".  We replace it with ┼ (U+253C) for a cleaner look.
(unless (display-graphic-p)
  (let ((table (or standard-display-table
                   (setq standard-display-table (make-display-table)))))
    (set-display-table-slot table 'vertical-border (make-glyph-code ?┼)))

  ;; Terminal emulators set their own buffer-local display table (for
  ;; truncation glyphs), which shadows the standard display table.
  ;; Re-apply the ┼ border glyph when eat-mode or vterm-mode activates.
  (add-hook 'eat-mode-hook
            (lambda ()
              (when-let ((table (or buffer-display-table
                                    (setq buffer-display-table (make-display-table)))))
                (set-display-table-slot table 'vertical-border
                                        (make-glyph-code ?┼)))))
  (add-hook 'vterm-mode-hook
            (lambda ()
              (when-let ((table (or buffer-display-table
                                    (setq buffer-display-table (make-display-table)))))
                (set-display-table-slot table 'vertical-border
                                        (make-glyph-code ?┼))))))

(provide 'panes)
;; panes.el ends here
