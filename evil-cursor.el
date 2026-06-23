;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  evil-cursor.el — Per-state terminal cursor color & shape
;;
;;  When running Emacs in a terminal (emacs -nw), changes the cursor
;;  appearance based on the current evil state using:
;;
;;    - OSC 12 / OSC 112  — cursor color
;;    - DECSCUSR          — cursor shape (CSI q sequences)
;;
;;  Normal mode  → Default color, default shape (reset)
;;  Insert mode  → #ff4400, bar (vertical line)
;;  Visual mode  → #ff4400, underline (horizontal bar)
;;
;;  Works by advising `evil-set-cursor', which evil calls on every state
;;  transition.  The :after advice sends both escape sequences — it runs
;;  after evil has already set Emacs' `cursor-type' variable, but since
;;  Emacs does not send DECSCUSR automatically in terminal mode, we send
;;  it ourselves to actually change the visible cursor.
;;
;;  Works in all buffers, including eat terminals, because
;;  `send-string-to-terminal' bypasses Emacs' internal buffer system and
;;  writes directly to the outer terminal's file descriptor.
;; =============================================================================

;; ── State → (color . shape) map ────────────────────────────────

(defvar my/evil-cursor-styles
  '((normal . (nil       . underline))
    (insert . ("#ff4400" . bar))
    (visual . ("#ff4400" . nil)))
  "Cursor (COLOR . SHAPE) per evil state.

COLOR is an X11 color string for OSC 12, or nil to reset to default.
SHAPE is a symbol among `bar', `underline', `box', or nil to reset.")

;; ── Terminal escape helpers ─────────────────────────────────────

(defun my/send-cursor-color (color)
  "Send OSC 12 to set cursor color to COLOR, or OSC 112 to reset."
  (if color
      (send-string-to-terminal (format "\033]12;%s\007" color))
    (send-string-to-terminal "\033]112\007")))

(defun my/send-cursor-shape (shape)
  "Send DECSCUSR to set cursor shape to SHAPE, or reset to default.

DECSCUSR (DEC Set Cursor Style) codes (steady variants):
  `box'       → CSI 2 q   (█)
  `underline' → CSI 4 q   (▁)
  `bar'       → CSI 6 q   (▎)
  nil         → CSI 0 q   (terminal default)"
  (let ((code (pcase shape
                ('bar       "6")
                ('underline "4")
                ('box       "2")
                (_          "0"))))
    (send-string-to-terminal (format "\033[%s q" code))))

;; ── Evil integration ────────────────────────────────────────────

(defun my/evil-set-cursor-appearance (&rest _args)
  "After `evil-set-cursor', send terminal escapes for current evil state.
Updates both color (OSC 12) and shape (DECSCUSR)."
  (when (not (display-graphic-p))
    (let ((style (alist-get evil-state my/evil-cursor-styles)))
      (my/send-cursor-color (car style))
      (my/send-cursor-shape (cdr style)))))

;; Hook into evil's cursor setup — runs on every state transition.
(advice-add 'evil-set-cursor :after #'my/evil-set-cursor-appearance)


(provide 'evil-cursor)
;; evil-cursor.el ends here
