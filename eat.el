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
Subtracts 7 for the letter label + separator prefix."
  (let ((window (car windows)))
    (when (window-live-p window)
      (cons (max (- (window-max-chars-per-line window) 7) 10)
            (window-text-height window)))))

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
                          #'my/eat-adjust-window-size))))

(provide 'eat)

;; eat.el ends here
