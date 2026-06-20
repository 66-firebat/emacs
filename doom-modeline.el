;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  doom-modeline.el — Doom Modeline Customization
;;
;;  A clean, informative mode line with Nerd Font icons.
;;  Terminal-friendly tweaks with a custom percentage display
;;  placed directly before the buffer name on the left side.
;; =============================================================================

;; ── Percentage function ──────────────────────────────────

(defun my/mode-line-percent ()
  "Return a Nerd Font icon representing the scroll position.
Maps 12.5%% bands to glyphs, like a scrollbar thumb."
  (let* ((total (max 1 (1- (point-max))))
         (pct (/ (float (1- (point))) total))
         (band (floor (* 8 pct))))
    (cond
     ((>= pct 1.0)        "󰪥")   ;; 100%%
     ((= band 0)          "󰰗")   ;;   0%% – 12.5%%
     ((= band 1)          "󰪞")   ;;  12.5%% – 25%%
     ((= band 2)          "󰪟")   ;;  25%% – 37.5%%
     ((= band 3)          "󰪠")   ;;  37.5%% – 50%%
     ((= band 4)          "󰪡")   ;;  50%% – 62.5%%
     ((= band 5)          "󰪢")   ;;  62.5%% – 75%%
     ((= band 6)          "󰪣")   ;;  75%% – 87.5%%
     ((= band 7)          "󰪤")   ;;  87.5%% – 100%% (exclusive)
     (t                   "󰪤")))) ;; edge case

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
  ;; Hide line number (redundant with statuscolumn)
  (setq doom-modeline-position-line-format nil)
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

  ;; Define a custom segment for percentage, then redefine the
  ;; main modeline to insert it before buffer-info.
  (doom-modeline-def-segment my-percent
    "Custom percentage: \" 85%\" before the buffer name."
    `(:propertize (:eval (concat " " (my/mode-line-percent)))
                  face ,(doom-modeline-face)
                  help-echo "Buffer percentage"
                  mouse-face 'doom-modeline-highlight
                  local-map mode-line-column-line-number-mode-map))

  ;; Redefine the main modeline to place my-percent before the buffer
  ;; name, and use my-buffer-info which puts the state icon after it.
  (doom-modeline-def-modeline 'main
    '(eldoc bar window-state workspace-name window-number
            modals matches follow my-percent my-buffer-info remote-host)
    '(compilation objed-state misc-info project-name persp-name
                  battery grip irc mu4e gnus github debug repl
                  minor-modes input-method indent-info buffer-encoding
                  process check time))
  ;; Apply the redefined modeline
  (doom-modeline-set-modeline 'main t))

(provide 'doom-modeline)
;; doom-modeline.el ends here
