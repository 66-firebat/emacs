;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  wl-clipboard.el — Wayland Clipboard Integration
;;
;;  Provides clipboard support for terminal Emacs (-nw) running under Wayland.
;;  Uses wl-copy / wl-paste (from the wl-clipboard package) to bridge Emacs'
;;  clipboard with the system clipboard.
;;
;;  Only activates when:
;;    1. The session type is "wayland"
;;    2. wl-copy and wl-paste are installed
;;    3. Emacs is running in terminal mode (non-graphical)
;; =============================================================================

(when (and (eq window-system nil)
           (string= (or (getenv "XDG_SESSION_TYPE") "") "wayland")
           (executable-find "wl-copy")
           (executable-find "wl-paste"))

  (defvar wl-copy-process nil
    "Persistent wl-copy process; keeps the clipboard valid until another
application requests the content (the `-f` flag).")

  (defun wl-copy (text)
    "Copy TEXT to the Wayland clipboard via wl-copy.
The `-f` flag keeps the process alive until the clipboard is claimed
by another application, which is required by Wayland's clipboard model.
The `-n` flag suppresses trailing newlines."
    (setq wl-copy-process
          (make-process :name "wl-copy"
                        :buffer nil
                        :command '("wl-copy" "-f" "-n")
                        :connection-type 'pipe))
    (process-send-string wl-copy-process text)
    (process-send-eof wl-copy-process))

  (defun wl-paste ()
    "Return the current Wayland clipboard content as a string.
Returns nil if Emacs itself owns the clipboard (the wl-copy process
is still live), preventing an unnecessary paste of our own content."
    (if (and wl-copy-process (process-live-p wl-copy-process))
        nil
      (let ((result (shell-command-to-string "wl-paste -n | tr -d \\\r")))
        (unless (string-empty-p result)
          result))))

  ;; Hook into Emacs' clipboard API
  (setq interprogram-cut-function #'wl-copy)
  (setq interprogram-paste-function #'wl-paste))

(provide 'wl-clipboard)
;; wl-clipboard.el ends here
