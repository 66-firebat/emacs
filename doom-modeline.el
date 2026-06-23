;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  doom-modeline.el — Doom Modeline Customization
;;
;;  A clean, informative mode line with Nerd Font icons.
;;  Shows the absolute line number before the buffer name.
;; =============================================================================

;; ── Modeline setup ───────────────────────────────────────

;; Nerd Icons font — required by doom-modeline for mode line icons
(use-package nerd-icons
  :commands nerd-icons-install-fonts
  :config
  (setq nerd-icons-font-family "Symbols Nerd Font Mono"))

(use-package doom-modeline
  :demand t
  :config
  (doom-modeline-mode 1)
  ;; Terminal-friendly tweaks
  (setq doom-modeline-height 1)
  (setq doom-modeline-bar-width 1)
  (setq doom-modeline-major-mode-icon t)
  (setq doom-modeline-minor-modes nil)
  (setq doom-modeline-enable-word-count nil)
  (setq doom-modeline-buffer-encoding nil)
  (setq doom-modeline-indent-info nil)
  (setq doom-modeline-env-version t)
  (setq doom-modeline-github nil)
  ;; Show line number in the mode-line (statuscolumn shows slice icon, not number)
  (setq doom-modeline-position-line-format '("L%l"))
  ;; Refresh mode-line on every cursor movement
  (add-hook 'post-command-hook #'force-mode-line-update nil 'local)

  ;; Custom buffer-info: buffer name followed by state icon.
  ;; Mode icon (/) removed — you already know what mode you're in.
  (doom-modeline-def-segment my-buffer-info
    "Buffer name with state icon after the name, no mode icon."
    (concat
     (doom-modeline-spc)
     (doom-modeline--buffer-name)
     " "
     (doom-modeline--buffer-state-icon)))

  ;; Show absolute line number before the buffer name.
  (doom-modeline-def-segment my-line-number
    "Line number: L42"
    `(:propertize (:eval (format-mode-line '("%l")))
                  face ,(doom-modeline-face)))

  ;; Redefine the main modeline, now with line number instead of percent.
  (doom-modeline-def-modeline 'main
    '(eldoc bar window-state workspace-name window-number
            modals matches follow my-line-number my-buffer-info remote-host)
    '(compilation objed-state misc-info project-name persp-name
                  battery grip irc mu4e gnus github debug repl
                  minor-modes input-method indent-info buffer-encoding
                  process check time))
  ;; Apply the redefined modeline
  (doom-modeline-set-modeline 'main t))

(provide 'doom-modeline)
;; doom-modeline.el ends here
