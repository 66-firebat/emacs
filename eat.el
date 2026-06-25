;; -*- lexical-binding: t; -*-

;; ── Terminal Width ──────────────────────────────────────────────────────────
;; eat-exec calls (eat-term-resize ... (window-max-chars-per-line) ...) which
;; sets the terminal too wide (130) — it doesn't account for statuscolumn's
;; 7-char line-prefix.  We advice eat-term-resize to detect this and subtract
;; the line-prefix width so the terminal is correct from the start.

(defun my/eat-adjust-window-size (process windows)
  "Return terminal size (WIDTH . HEIGHT) accounting for statuscolumn.
Used by window--adjust-process-windows for ongoing resize handling."
  (condition-case nil
      (let ((window (car windows)))
        (when (window-live-p window)
          (let* ((mcl (window-max-chars-per-line window))
                 (lp (buffer-local-value 'line-prefix (window-buffer window)))
                 (lpw (if (and (stringp lp) (> (length lp) 0))
                          (string-width lp) 0))
                 (tw (max (- mcl lpw) 1)))
            (cons tw (window-text-height window)))))
    (error nil)))

(defun my/eat-resize-correct-line-prefix (fn terminal width height)
  "When eat resizes to window-max-chars-per-line, subtract line-prefix."
  (let* ((buf (ignore-errors (eat--t-term-buffer terminal)))
         (corrected width))
    (when buf
      (let* ((win (get-buffer-window buf t))
             (mcl (and win (window-max-chars-per-line win)))
             (lp (buffer-local-value 'line-prefix buf))
             (lpw (if (and (stringp lp) (> (length lp) 0))
                      (string-width lp) 0)))
        ;; If this resize matches the uncorrected window width,
        ;; subtract the line-prefix to account for the statuscolumn.
        (when (and mcl (> lpw 0) (= width mcl))
          (setq corrected (max (- width lpw) 1)))))
    (funcall fn terminal corrected height)))

;; ── use-package ─────────────────────────────────────────────────────────────

(use-package eat
  :ensure t
  :config
  (setq eat-enable-shell-integration t)
  (setq eat-default-input-mode 'semi-char)
  (setq eat-enable-shell-prompt-annotation nil)
  (setq eat-term-scrollback-size nil)

  (add-hook 'eat-mode-hook
            (lambda ()
              (setq-local window-adjust-process-window-size-function
                          #'my/eat-adjust-window-size)))

  (remove-hook 'eat-update-hook #'sc--on-eat-update)

  (defun my/eat-snap-cursor-on-insert ()
    (when (and (derived-mode-p 'eat-mode) (bound-and-true-p eat-terminal))
      (let ((pos (ignore-errors (eat-term-display-cursor eat-terminal))))
        (when (and pos (<= (point-min) pos (point-max)) (/= pos (point)))
          (goto-char pos)))))
  (add-hook 'evil-insert-state-entry-hook #'my/eat-snap-cursor-on-insert))

;; ── Advice ──────────────────────────────────────────────────────────────────
;; Fix initial terminal width by intercepting eat-term-resize
(advice-add 'eat-term-resize :around #'my/eat-resize-correct-line-prefix)

(provide 'eat)
