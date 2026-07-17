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

  (defun my/eat-snap-cursor-on-insert ()
    (when (and (derived-mode-p 'eat-mode) (bound-and-true-p eat-terminal))
      (let ((pos (ignore-errors (eat-term-display-cursor eat-terminal))))
        (when (and pos (<= (point-min) pos (point-max)) (/= pos (point)))
          (goto-char pos)))))
  (add-hook 'evil-insert-state-entry-hook #'my/eat-snap-cursor-on-insert))

;; ── Advice ──────────────────────────────────────────────────────────────────
;; Fix initial terminal width by intercepting eat-term-resize
(advice-add 'eat-term-resize :around #'my/eat-resize-correct-line-prefix)

;; ── Spawn Terminal (M-t) ─────────────────────────────────────────────────────
;; Indexed eat sessions: buffers are named "<index>  <PID>" and the lowest
;; free index is reused first.  Bound to M-t in keybinds.el.

(defun my/eat-next-available ()
  "Return the lowest unused eat index (1, 2, 3, ...).
Scans all buffer names for \"<N> \" prefixes."
  (let ((i 1))
    (while (let ((target (format "%d " i)))
             (catch 'exists
               (dolist (b (buffer-list) nil)
                 (when (string-prefix-p target (buffer-name b))
                   (throw 'exists t)))))
      (setq i (1+ i)))
    i))

(defun my/eat-new ()
  "Spawn a new eat terminal at the lowest available index.
Buffer is named like \"1  19950\" (index +  + PID)."
  (interactive)
  (let ((index (my/eat-next-available))
        (shell (or explicit-shell-file-name
                   (getenv "ESHELL")
                   shell-file-name))
        (cwd default-directory))
    (let ((buf-name (format "%d  waiting" index)))
      (with-current-buffer (get-buffer-create buf-name)
        (setq default-directory cwd)
        (eat-mode)
        (pop-to-buffer-same-window (current-buffer))
        (unless (and eat-terminal
                     (eat-term-parameter eat-terminal 'eat--process))
          (eat-exec (current-buffer) (buffer-name)
                    "/usr/bin/env" nil
                    (list "sh" "-c" shell)))
        ;; Rename buffer to include the PID
        (when-let* ((proc (eat-term-parameter eat-terminal 'eat--process))
                    ((process-live-p proc)))
          (rename-buffer (format "%d  %d" index (process-id proc))))
        (current-buffer)))))

(provide 'eat-firemacs)
