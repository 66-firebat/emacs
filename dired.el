;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  dired.el — Dired customizations
;;
;;  - RET opens directories in the current buffer (instead of creating a new one)
;;  - ^ / - go up a directory in the current buffer
;;  - C-e toggles dired open/closed (defined in keybinds.el)
;; =============================================================================

;; Enable `dired-find-alternate-file' (it's disabled by default because it's
;; "dangerous", but we use it intentionally to reuse the dired buffer).
(put 'dired-find-alternate-file 'disabled nil)

;; When copying/moving files, automatically suggest the adjacent dired buffer's
;; directory as the target (dwim = "do what I mean").
(setq dired-dwim-target t)

(defun my/dired-up-directory ()
  "Go up one directory, reusing the current dired buffer."
  (interactive)
  (find-alternate-file ".."))

;; Use evil-define-key (via general-def) to override evil-collection's
;; bindings.  Plain define-key on dired-mode-map won't work because
;; evil-collection puts its bindings in evil auxiliary keymaps which
;; take priority over dired-mode-map.
;;
;; This runs after evil-collection-dired-setup because dired.el is
;; loaded after evil-collection in init.el, so our bindings win.
(general-def 'normal dired-mode-map
  "RET" 'dired-find-alternate-file
  "^"   'my/dired-up-directory
  "-"   'my/dired-up-directory)


(provide 'dired-overrides)
;; dired.el ends here
