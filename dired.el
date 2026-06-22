;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  dired.el — Dired customizations
;;
;;  - RET opens directories in the current buffer (instead of creating a new one)
;;  - ^ goes up a directory in the current buffer
;;  - C-e toggles dired open/closed (defined in keybinds.el)
;; =============================================================================

;; Enable `dired-find-alternate-file' (it's disabled by default because it's
;; "dangerous", but we use it intentionally to reuse the dired buffer).
(put 'dired-find-alternate-file 'disabled nil)

(with-eval-after-load 'dired
  ;; RET opens directories in the same buffer instead of spawning a new one
  (define-key dired-mode-map (kbd "RET") #'dired-find-alternate-file)

  ;; ^ goes up a directory in the same buffer
  (define-key dired-mode-map (kbd "^")
    (lambda () (interactive) (find-alternate-file ".."))))


(provide 'dired)
;; dired.el ends here
