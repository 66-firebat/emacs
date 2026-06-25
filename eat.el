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
Computes terminal width directly from window geometry, avoiding
unreliable `window-max-chars-per-line' caching across buffers."
  (let ((window (car windows)))
    (when (window-live-p window)
      (let* ((buf (window-buffer window))
             ;; Total window width (all columns, including margins).
             (total (window-total-width window))
             ;; Window margin columns — protect against nil from either side.
             (margins (window-margins window))
             (left-margin (if margins (or (car margins) 0) 0))
             (right-margin (if margins (or (cdr margins) 0) 0))
             ;; Text area = total minus margin columns.
             (text-width (- total left-margin right-margin))
             ;; Statuscolumn line-prefix width.
             (lp (buffer-local-value 'line-prefix buf))
             (lp-width (if (and (stringp lp) (> (length lp) 0))
                           (string-width lp)
                         8))
             ;; Terminal content width = text area minus line-prefix.
             (term-width (max (- text-width lp-width) 10))
             ;; Also compute via window-max-chars-per-line for comparison.
             (mcl (window-max-chars-per-line window)))
        ;; Debug: log measured values.
        (condition-case nil
            (let ((msg (format "total=%d margins=(%d,%d) text=%d lp=%d mcl=%d term=%d"
                               total left-margin right-margin text-width
                               lp-width mcl term-width)))
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

  ;; Disable eat's shell prompt annotation margin — sc-mode already
  ;; manages the left margin for the statuscolumn.  Having both eat
  ;; and sc-mode fight over left-margin-width causes erratic terminal
  ;; width calculations and line-wrapping corruption on the second
  ;; spawned eat buffer.
  (setq eat-enable-shell-prompt-annotation nil)

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
