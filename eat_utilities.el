;;; eat_utilities.el --- Eat terminal integration for Grease  -*- lexical-binding: t; -*-

;;; Commentary:
;; Utilities for synchronising Grease with an Eat terminal.  When enabled,
;; quitting Grease sends a `cd' command to the originating Eat terminal's
;; shell process, changing its working directory to the last Grease directory.

;;; Code:

(defcustom grease-eat-cd-on-quit t
  "When non-nil, send `cd' to originating Eat terminal on Grease quit.
The Eat buffer that was current before Grease was opened will have its
shell changed to the last directory browsed in Grease.
Requires `eat' to be loaded."
  :type 'boolean
  :group 'grease)

(defvar grease--origin-buffer nil
  "Buffer that was current when Grease was opened, for `grease-eat-cd-on-quit'.")

(defun grease--cd-origin-eat ()
  "Send `cd' to the origin Eat buffer, if any.
The origin buffer is saved by `grease-toggle' when opening Grease from
a non-Grease buffer."
  (let ((dir grease--root-dir))
    (when (and grease--origin-buffer
               (buffer-live-p grease--origin-buffer)
               grease-eat-cd-on-quit
               (fboundp 'eat--send-string))
      (with-current-buffer grease--origin-buffer
        (when (eq major-mode 'eat-mode)
          (when-let ((proc (eat-term-parameter
                            (bound-and-true-p eat-terminal)
                            'eat--process)))
            (eat--send-string proc (format "cd %s\n" dir))
            (message "Grease: Sent cd to Eat for %s" dir))))
      (setq grease--origin-buffer nil))))

(provide 'eat_utilities)
;;; eat_utilities.el ends here
