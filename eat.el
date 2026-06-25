;; -*- lexical-binding: t; -*-

(defun my/eat-msg (fmt &rest args)
  (message "[eat] %s" (apply #'format fmt args)))

;; ── Terminal Width ──────────────────────────────────────────────────────────

(defun my/eat-adjust-window-size (process windows)
  "Return terminal size (WIDTH . HEIGHT) for the eat window."
  (condition-case err
      (let ((window (car windows)))
        (when (window-live-p window)
          (let* ((buf (window-buffer window))
                 (mcl (window-max-chars-per-line window))
                 (lp (buffer-local-value 'line-prefix buf))
                 (lpw (if (and (stringp lp) (> (length lp) 0))
                          (string-width lp) 0))
                 (tw (max (- mcl lpw) 1)))
            (my/eat-msg "WIDTH window=%s mcl=%d lp=%S(lpw=%d) → term=%d"
                         (window-buffer window) mcl lp lpw tw)
            (cons tw (window-text-height window)))))
    (error
     (my/eat-msg "WIDTH-ERROR: %s" (error-message-string err))
     nil)))

;; ── Fix Width via Timer ─────────────────────────────────────────────────────
;; eat-exec-hook fires BEFORE the buffer has a window (display happens
;; after eat-exec returns).  We schedule a 0-second timer to correct
;; the width once the window exists.

(defun my/eat-fix-width-now ()
  "Correct terminal width RIGHT NOW. Must be called from eat buffer."
  (when-let* ((term (bound-and-true-p eat-terminal))
              (win (get-buffer-window (current-buffer) t))
              (sz (my/eat-adjust-window-size nil (list win)))
              (old (ignore-errors (eat-term-size term))))
    (when (/= (car old) (car sz))
      (my/eat-msg "RESIZE: %d → %d" (car old) (car sz))
      (eat-term-resize term (car sz) (cdr sz))
      (when-let ((proc (eat-term-parameter term 'eat--process)))
        (ignore-errors (signal-process (process-id proc) 'SIGWINCH))))))

(defun my/eat-schedule-fix (&rest _)
  "Schedule terminal width correction after window appears."
  (my/eat-msg "SCHEDULE-FIX: buf=%s" (buffer-name))
  (run-with-timer 0.1 nil
                  (lambda (buf)
                    (when (buffer-live-p buf)
                      (with-current-buffer buf
                        (my/eat-msg "TIMER-FIRE: buf=%s" (buffer-name))
                        (my/eat-fix-width-now))))
                  (current-buffer)))

;; ── C0 Filter + Buffer Tracer ──────────────────────────────────────────────

(defun my/eat-strip-c0 (fn terminal output)
  "Strip unhandled C0 bytes, then process and log buffer state."
  (condition-case err
      (let* ((n0 (length output))
             (cleaned (cl-remove-if
                       (lambda (c)
                         (and (<= c 31) (/= c 9) (/= c 10) (/= c 13)
                              (not (memq c '(?\a ?\b ?\n ?\v ?\f ?\r
                                              ?\C-n ?\C-o ?\e ?\0)))))
                       output))
             (n1 (length cleaned))
             (nrem (- n0 n1)))
        (when (> nrem 0)
          (my/eat-msg "C0: removed %d (SOH=%d STX=%d) in %d-byte chunk"
                       nrem
                       (cl-count-if (lambda (c) (= c 1)) output)
                       (cl-count-if (lambda (c) (= c 2)) output)
                       n0))
        (funcall fn terminal cleaned)
        ;; Log buffer rows
        (let* ((buf (ignore-errors (eat--t-term-buffer terminal)))
               (w (car (ignore-errors (eat-term-size terminal))))
               (rows '()))
          (when buf
            (with-current-buffer buf
              (let ((beg (ignore-errors (eat-term-beginning terminal)))
                    (end (ignore-errors (eat-term-end terminal))))
                (when (and beg end)
                  (save-excursion
                    (goto-char beg)
                    (while (< (point) end)
                      (push (- (line-end-position) (point)) rows)
                      (forward-line 1))))))
            (let ((r (nreverse rows)))
              (my/eat-msg "BUF: w=%d rows=%d lens=%s"
                           w (length r)
                           (if (<= (length r) 12) r
                             (append (cl-subseq r 0 6) (list :::)
                                     (cl-subseq r -3 nil))))))))
    (error
     (my/eat-msg "C0-ERROR: %s" (error-message-string err))
     (funcall fn terminal output))))

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
              (my/eat-msg "MODE-HOOK: buf=%s lp=%S"
                           (buffer-name)
                           (buffer-local-value 'line-prefix (current-buffer)))
              (setq-local window-adjust-process-window-size-function
                          #'my/eat-adjust-window-size)))

  ;; Schedule width correction 100ms after shell spawns (when window exists)
  (add-hook 'eat-exec-hook #'my/eat-schedule-fix)
  (remove-hook 'eat-update-hook #'sc--on-eat-update)

  (defun my/eat-snap-cursor-on-insert ()
    (when (and (derived-mode-p 'eat-mode) (bound-and-true-p eat-terminal))
      (let ((pos (ignore-errors (eat-term-display-cursor eat-terminal))))
        (when (and pos (<= (point-min) pos (point-max)) (/= pos (point)))
          (goto-char pos)))))
  (add-hook 'evil-insert-state-entry-hook #'my/eat-snap-cursor-on-insert))

(advice-add 'eat-term-process-output :around #'my/eat-strip-c0)

(provide 'eat)
