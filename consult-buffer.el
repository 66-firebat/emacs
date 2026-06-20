;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  consult-buffer.el — Consult configuration & custom sources
;;
;;  General Consult configuration and all custom `consult-buffer' sources live
;;  here.  Loaded eagerly — no `with-eval-after-load'.
;; =============================================================================

;; ── VTerm source ───────────────────────────────────────────────
;; Allows typing a number in SPC b b (consult-buffer) to spawn a
;; vterm at that index.  Existing vterm buffers appear as candidates.
;;
;; IMPORTANT — :default t + prepend
;; ---------------------------------
;; When a user types text that doesn't match any candidate,
;; `consult--multi-lookup' picks the FIRST source with :default t and
;; calls its :new function.  If we're not the default, consult falls
;; through to `consult-source-buffer' (which has no :new) and creates
;; a plain Fundamental buffer.  We MUST be the default source so our
;; :new is called.
;;
;; Our :new handles both cases:
;;   "90"         → spawn vterm at index 90
;;   "README.md"  → create a regular buffer (via consult--buffer-action)

(defvar my/consult-vterm-source
  `(:name     "VTerm"
    :category buffer
    :default  t                    ;; <-- consult-multi-lookup picks us first
    :face     consult-buffer
    :history  buffer-name-history
    :state    ,#'consult--buffer-state
    :new      ,(lambda (name)
                 (if (string-match-p "\\`[0-9]+\\'" name)
                     ;; Numeric → spawn vterm at that index
                     (let ((buf (my/vterm-spawn-at-index (string-to-number name))))
                       (when buf
                         (consult--buffer-action buf)))
                   ;; Non-numeric → create a regular buffer (same fallback
                   ;; consult-buffer would normally do)
                   (consult--buffer-action name)))
    :items    ,(lambda ()
                 (mapcar #'buffer-name (my/vterm-buffer-list))))
  "Custom consult-buffer source for vterm buffers.
Allows spawning a new vterm by entering its index.
Uses `my/vterm-spawn-at-index' and `my/vterm-buffer-list' from keybinds.el.")

;; Prepend so our source is found FIRST by `consult--multi-lookup'
;; (since both we and consult-source-buffer have :default t).
(add-to-list 'consult-buffer-sources 'my/consult-vterm-source)

;; ── Future consult sources go here ──────────────────────────────

(provide 'consult-buffer)
;; consult-buffer.el ends here
