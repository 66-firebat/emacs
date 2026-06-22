;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  consult-buffer.el — Consult configuration & custom sources
;;
;;  General Consult configuration and all custom `consult-buffer' sources live
;;  here.  Loaded eagerly — no `with-eval-after-load'.
;; =============================================================================

;; ── Eat source ────────────────────────────────────────────────
;; Allows typing a number in SPC b b (consult-buffer) to spawn an
;; eat terminal at that index.  Existing eat buffers appear as candidates.
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
;;   "90"         → spawn eat terminal at index 90
;;   "README.md"  → create a regular buffer (via consult--buffer-action)

(defvar my/consult-eat-source
  `(:name     "Eat"
    :category buffer
    :default  t                    ;; <-- consult-multi-lookup picks us first
    :face     consult-buffer
    :history  buffer-name-history
    :state    ,#'consult--buffer-state
    :new      ,(lambda (name)
                 (if (string-match-p "\\`[0-9]+\\'" name)
                     ;; Numeric → spawn eat at that index
                     (let ((buf (my/eat-spawn-at-index (string-to-number name))))
                       (when buf
                         (consult--buffer-action buf)))
                   ;; Non-numeric → create a regular buffer (same fallback
                   ;; consult-buffer would normally do)
                   (consult--buffer-action name)))
    :items    ,(lambda ()
                 (mapcar #'buffer-name (my/eat-buffer-list))))
  "Custom consult-buffer source for eat terminals.
Allows spawning a new eat by entering its index.
Uses `my/eat-spawn-at-index' and `my/eat-buffer-list' from keybinds.el.")

;; Prepend so our source is found FIRST by `consult--multi-lookup'
;; (since both we and consult-source-buffer have :default t).
(add-to-list 'consult-buffer-sources 'my/consult-eat-source)

;; ── Future consult sources go here ──────────────────────────────

(provide 'consult-buffer)
;; consult-buffer.el ends here
