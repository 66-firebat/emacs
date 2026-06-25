;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  embark.el — Embark: context-aware actions in the minibuffer and beyond
;;
;;  Provides:
;;    - C-; (embark-act) — act on the current completion candidate or thing
;;      at point (files, buffers, bookmarks, symbols, etc.)
;;    - C-d in consult-buffer — directly kill the selected buffer
;;    - Full embark-consult integration for consult-buffer type detection
;; =============================================================================

;; ── Packages ────────────────────────────────────────────────────

(use-package embark
  :ensure t
  :demand t
  :bind
  ;; C-; is the main "act on this" key — works in the minibuffer,
  ;; in consult-buffer, on files/symbols/URLs at point, etc.
  ("C-;" . embark-act)
  :config
  ;; Show available actions in a popup buffer (like which-key for embark)
  (setq embark-prompter 'embark-verbose-prompter))

;; embark-consult provides correct action types for consult-buffer
;; (buffers get buffer actions, recent files get file actions, etc.)
;; It's auto-loaded by embark when consult is present.
(use-package embark-consult
  :ensure t
  :demand t)

;; ── Kill buffer directly from consult-buffer ────────────────────
;; C-d kills the selected buffer and keeps the minibuffer open.
;; Defined inside with-eval-after-load so vertico symbols are available.

(with-eval-after-load 'vertico
  (defun my/consult-kill-buffer ()
    "Kill the buffer at point in the minibuffer completion list.
Kills aggressively: no prompts, no confirmations, no save queries.
Refreshes the candidate list in place via vertico."
    (interactive)
    (let* ((raw (vertico--candidate))
           ;; Strip consult's internal "tofu" characters from the candidate
           (candidate (if (and raw (fboundp 'consult--tofu-strip))
                          (consult--tofu-strip raw)
                        raw)))
      (when-let ((buffer (and candidate (get-buffer candidate))))
        ;; Kill the buffer without any prompts or confirmations
        (with-current-buffer buffer
          (let ((kill-buffer-query-functions nil))
            (set-buffer-modified-p nil)
            (kill-buffer)))
        ;; Exit the minibuffer and re-run consult-buffer via a timer.
        ;; This gives consult-buffer a completely fresh start,
        ;; guaranteeing the killed buffer won't appear.
        (let ((input (minibuffer-contents)))
          (abort-recursive-edit)
          (run-with-idle-timer 0.01 nil
            (lambda ()
              (let ((consult--buffer-history (list input)))
                (consult-buffer))))))))

  ;; Bind C-d in vertico-map (active during all Vertico completion sessions,
  ;; including consult-buffer). The function safely ignores non-buffer
  ;; candidates like files and bookmarks.
  (keymap-set vertico-map "C-d" #'my/consult-kill-buffer))


(provide 'embark)
;; embark.el ends here
