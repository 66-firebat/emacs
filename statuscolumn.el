;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  statuscolumn.el — Visual separator for Emacs' built-in line numbers
;;
;;  Uses ZERO per-visual-line overlays.  Instead, Emacs' C display engine
;;  handles everything:
;;
;;    1. Line numbers    — `display-line-numbers 'visual' (C engine)
;;    2. Separator ┃/┣  — `line-prefix' + `wrap-prefix' variables (C engine)
;;    3. Cursor line ┣   — Single overlay overriding line-prefix on cursor line
;;    4. Diff-hl icons   — diff-hl-fallback-to-margin (for terminal)
;;
;;  Benefits: zero flicker, works in ALL modes (eat, vterm, GUI, TTY),
;;  minimal Elisp code, no overlay management.
;; =============================================================================

;; ═════════════════════════════════════════════════════════════════════════════
;;  Faces
;; ═════════════════════════════════════════════════════════════════════════════

(defface sc-separator
  '((t (:foreground "#444444")))
  "Face for the statuscolumn separator ┃ on non-current lines."
  :group 'statuscolumn)

(defface sc-bump
  '((t (:foreground "#ff4400" :weight bold)))
  "Face for the current-line separator ┣ (firebat accent)."
  :group 'statuscolumn)

;; ═════════════════════════════════════════════════════════════════════════════
;;  Internal variables
;; ═════════════════════════════════════════════════════════════════════════════

(defvar-local sc--cursor-overlay nil
  "Single overlay on the cursor line that overrides `line-prefix' to ┣.")

(defvar-local sc--prefix-string nil
  "Cached propertized separator string (┃) for non-cursor lines.")

(defvar-local sc--bump-prefix-string nil
  "Cached propertized separator string (┣) for the cursor line.")

;; ═════════════════════════════════════════════════════════════════════════════
;;  Core — update the single cursor-line overlay
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--update ()
  "Move the ┣ overlay to the cursor's line.
This is the ONLY dynamic element — everything else is handled by the
C display engine via `line-prefix' and `wrap-prefix' variables."
  (let ((bol (line-beginning-position))
        (eol (line-beginning-position 2)))
    (if (and sc--cursor-overlay
             (overlay-buffer sc--cursor-overlay)
             (= (overlay-start sc--cursor-overlay) bol))
        ;; Overlay is already at the right position — nothing to do
        nil
      ;; Move or create the overlay
      (if (and sc--cursor-overlay (overlay-buffer sc--cursor-overlay))
          (move-overlay sc--cursor-overlay bol eol)
        (setq sc--cursor-overlay
              (let ((ov (make-overlay bol eol nil t)))
                (overlay-put ov 'line-prefix sc--bump-prefix-string)
                (overlay-put ov 'wrap-prefix sc--bump-prefix-string)
                (overlay-put ov 'evaporate t)
                ov))))))

(defun sc--clear ()
  "Remove the cursor overlay."
  (when sc--cursor-overlay
    (delete-overlay sc--cursor-overlay)
    (setq sc--cursor-overlay nil)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Hooks
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-post-command ()
  "Update the cursor-line ┣ overlay after any command.
Just moves one overlay — no visual line walking, no flicker."
  (when (and (local-variable-p 'sc--cursor-overlay (current-buffer))
             (not (minibufferp)))
    (sc--update)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Minor mode — configures C engine for statuscolumn display
;; ═════════════════════════════════════════════════════════════════════════════

(define-minor-mode sc-mode
  "Configure the C display engine for statuscolumn rendering.

Sets up `display-line-numbers', `line-prefix', and `wrap-prefix' so
that every visual line shows ┃ after the line number.  A single overlay
on the cursor line shows ┣ instead.

Works in all modes (eat, vterm, GUI, TTY) because everything is handled
by Emacs' C display engine."
  :lighter ""
  :global nil
  (if sc-mode
      ;; ── Enable ────────────────────────────────────────────
      (progn
        ;; Cache propertized separator strings
        (setq-local sc--prefix-string (propertize "┃ " 'face 'sc-separator))
        (setq-local sc--bump-prefix-string (propertize "┣ " 'face 'sc-bump))

        ;; Turn on display-line-numbers (C engine)
        (unless (bound-and-true-p display-line-numbers-mode)
          (display-line-numbers-mode 1))
        (setq-local display-line-numbers 'visual)
        (setq-local display-line-numbers-current-absolute t)
        (setq-local display-line-numbers-grow-only t)
        (setq-local display-line-numbers-width 5)

        ;; Set line-prefix and wrap-prefix (C engine adds ┃ after number)
        (setq-local line-prefix sc--prefix-string)
        (setq-local wrap-prefix sc--prefix-string)

        ;; Create cursor-line overlay for ┣
        (sc--update)

        ;; Keep cursor overlay in sync
        (add-hook 'post-command-hook #'sc--on-post-command nil 'local))

    ;; ── Disable ────────────────────────────────────────────
    (progn
      (remove-hook 'post-command-hook #'sc--on-post-command 'local)
      (sc--clear)
      (kill-local-variable 'line-prefix)
      (kill-local-variable 'wrap-prefix)
      (kill-local-variable 'display-line-numbers))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Global mode — activate in every buffer
;; ═════════════════════════════════════════════════════════════════════════════

(define-minor-mode global-sc-mode
  "Toggle statuscolumn separators in every buffer."
  :global t
  :lighter ""
  (if global-sc-mode
      (progn
        (global-sc-mode--enable-all)
        (add-hook 'after-change-major-mode-hook
                  #'global-sc-mode--enable-buffer))
    (global-sc-mode--disable-all)
    (remove-hook 'after-change-major-mode-hook
                 #'global-sc-mode--enable-buffer)))

(defun global-sc-mode--enable-buffer ()
  "Enable `sc-mode' in current buffer."
  (when global-sc-mode
    (sc-mode 1)))

(defun global-sc-mode--enable-all ()
  "Apply global statuscolumn setup."
  ;; Clean up any stale diff-hl margin mode
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (bound-and-true-p diff-hl-margin-mode)
        (diff-hl-margin-mode -1))
      (setq left-margin-width 0)
      (when (get-buffer-window buf t)
        (set-window-margins (get-buffer-window buf t) 0
                            (cdr (window-margins (get-buffer-window buf t)))))))
  ;; Set global defaults for C engine
  (setq-default display-line-numbers-type 'visual
                display-line-numbers 'visual
                display-line-numbers-current-absolute t
                display-line-numbers-grow-only t
                display-line-numbers-width 5)
  ;; Enable sc-mode in all buffers
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (sc-mode 1))))

(defun global-sc-mode--disable-all ()
  "Revert global statuscolumn setup."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when sc-mode (sc-mode -1)))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Provide
;; ═════════════════════════════════════════════════════════════════════════════

(provide 'statuscolumn)

;; statuscolumn.el ends here
