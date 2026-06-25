;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  eat.el — Terminal Emulator Configuration
;;
;;  Accounts for the statuscolumn's letter label + separator width when
;;  calculating the terminal width, preventing content overflow.
;;
;;  The statuscolumn adds 7 chars per line via `line-prefix' overlays:
;;    "  a  ┃ " = 7 chars (leading space + mark/space + space + label + 2 spaces + separator)
;;
;;  `window-max-chars-per-line' accounts for fringes, scrollbars, and
;;  margins (left-margin-width) but NOT for `line-prefix' overlays.
;;  We subtract 7 to compensate.
;; =============================================================================

(defun my/eat-adjust-window-size (process windows)
  "Return terminal size (WIDTH . HEIGHT) accounting for the statuscolumn.
PROCESS is the Eat shell process.  WINDOWS is the list of windows
displaying the process's buffer.
Computes terminal width as `window-body-width' minus the statuscolumn's
`line-prefix' width, measured dynamically via `string-width'."
  (let ((window (car windows)))
    (when (window-live-p window)
      (let* ((buf (window-buffer window))
             ;; Measure available width.
             (chars-per-line (window-max-chars-per-line window))
             ;; Read the buffer-local line-prefix (set by sc--init).
             (lp (buffer-local-value 'line-prefix buf))
             (lp-width (if (and (stringp lp) (> (length lp) 0))
                           (string-width lp)
                         8))
             ;; Also measure the raw window width for comparison.
             (raw-window-width (window-width window))
             (body-width (window-body-width window))
             (term-width (max (- chars-per-line lp-width) 10)))
        ;; Debug: log measured values to a file.
        (condition-case nil
            (let* ((margins (window-margins window))
                   (lm (car margins))
                   (rm (cdr margins))
                   (lm-buf (buffer-local-value 'left-margin-width buf))
                   (msg (format "raw=%d body=%d mcl=%d lp='%s'(%d) term=%d margins=(%s,%d,%d)"
                                raw-window-width body-width chars-per-line
                                (if (stringp lp) lp "[nil]") lp-width term-width
                                (if margins (format "%S" margins) "nil")
                                (if (numberp lm) lm -1) lm-buf)))
              (with-temp-buffer
                (insert (format-time-string "%H:%M:%S")
                        (format " eat-adjust: %s\n" msg))
                (append-to-file (point-min) (point-max) "/tmp/eat-debug.log"))
              (message "eat-adjust: %s" msg))
          (error nil))
        (cons term-width
              (window-text-height window))))))

(use-package eat
  :ensure t
  :config
  (setq eat-enable-shell-integration t)
  (setq eat-default-input-mode 'semi-char)

  ;; Unlimited scrollback: eat normally keeps only the most recent
  ;; 131072 characters (128 KB) of terminal output and deletes older
  ;; content.  Setting to nil disables this truncation entirely, so
  ;; you can scroll back through the ENTIRE terminal session history.
  (setq eat-term-scrollback-size nil)

  ;; Eat's directory tracking updates `default-directory' when the shell
  ;; reports its working directory via OSC 7.  For this to work, your
  ;; .bashrc needs shell integration:
  ;;
  ;;   [ -n "$EAT_SHELL_INTEGRATION_DIR" ] && \
  ;;     source "$EAT_SHELL_INTEGRATION_DIR/bash"
  ;;
  ;; Once set up, `default-directory' in eat buffers tracks `cd' commands.
  ;; `my/dired-from-eat' uses this to open dired in the eat terminal's
  ;; current directory.

  (add-hook 'eat-mode-hook
            (lambda ()
              (setq-local window-adjust-process-window-size-function
                          #'my/eat-adjust-window-size)))

  ;; Cursor snapping: when entering insert mode in an eat terminal,
  ;; move Emacs point to the terminal's actual cursor position.
  ;; Without this, Evil's point can be anywhere in the buffer (from
  ;; normal-mode navigation), but the terminal expects input at its
  ;; own cursor location.  `eat-term-display-cursor' returns the
  ;; Emacs buffer position corresponding to the terminal's cursor.
  (defun my/eat-snap-cursor-on-insert ()
    "Move point to terminal cursor when entering insert state.
Added to `evil-insert-state-entry-hook'."
    (when (and (derived-mode-p 'eat-mode)
               (bound-and-true-p eat-terminal))
      (let ((pos (condition-case nil
                     (eat-term-display-cursor eat-terminal)
                   (error nil))))
        (when (and pos (<= (point-min) pos (point-max))
                   (/= pos (point)))
          (goto-char pos)))))

  (add-hook 'evil-insert-state-entry-hook #'my/eat-snap-cursor-on-insert))

(provide 'eat)

;; eat.el ends here
