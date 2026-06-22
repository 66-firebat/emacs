;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  eat.el — Terminal Emulator Configuration
;;
;;  Accounts for the statuscolumn width (line numbers + ┃ separator) when
;;  calculating the terminal width, preventing content overflow.
;;
;;  The key variable is `window-adjust-process-window-size-function'.
;;  Eat calls this to get (WIDTH . HEIGHT) for the terminal.  The default
;;  uses `window-max-chars-per-line' which accounts for `display-line-numbers'
;;  but NOT for `line-prefix' (our ┃ separator).  We override it to subtract
;;  the prefix width (2 chars: space + ┃).
;; =============================================================================

(defun my/eat-adjust-window-size (process windows)



  "Return terminal size (WIDTH . HEIGHT) accounting for the statuscolumn.
PROCESS is the Eat shell process.  WINDOWS is the list of windows
displaying the process's buffer.
Subtracts 2 from the available width for the `line-prefix' separator."
  (let ((window (car windows)))
    (when (window-live-p window)
      (cons (max (- (window-max-chars-per-line window) 2) 10)
            (window-text-height window)))))

(use-package eat
  :ensure t
  :config
  (setq eat-enable-shell-integration t)
  (setq eat-default-input-mode 'semi-char)

  ;; Eat's directory tracking updates `default-directory' when the shell
  ;; reports its working directory via OSC 7.  For this to work, your
  ;; .bashrc needs shell integration:
  ;;
  ;;   [ -n "$EAT_SHELL_INTEGRATION_DIR" ] && \
  ;;     source "$EAT_SHELL_INTEGRATION_DIR/bash"
  ;;
  ;; Once set up, `default-directory' in eat buffers tracks `cd' commands.
  ;; `my/dired-from-eat' (SPC d d) uses this to open dired in the eat
  ;; terminal's current directory.

  ;; Override terminal width calculation to account for the statuscolumn
  ;; `line-prefix' (2 chars).  This must be set buffer-locally in each eat
  ;; buffer via `eat-mode-hook'.  See `window-adjust-process-window-size-
  ;; function' in the Emacs Lisp manual for details.
  (add-hook 'eat-mode-hook
            (lambda ()
              (setq-local window-adjust-process-window-size-function
                          #'my/eat-adjust-window-size))))

(provide 'eat)
