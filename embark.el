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
;; C-u C-d kills the buffer and restarts consult-buffer (closes & reopens).
;; Defined inside with-eval-after-load so vertico symbols are available.

(with-eval-after-load 'vertico
  (defun my/consult-kill-buffer (&optional arg)
    "Kill the buffer at point in the minibuffer completion list.

Kills aggressively: no prompts, no confirmations, no save queries.

With \\[universal-argument] (C-u), close and restart consult-buffer
after killing (old behavior).
Without prefix (C-d), refresh the candidate list in place and keep
the minibuffer open."
    (interactive "P")
    (let* ((raw (vertico--candidate))
           ;; Strip consult's internal "tofu" characters from the candidate.
           ;; This gives us the plain buffer name, captured BEFORE kill.
           (buf-name (if (and raw (fboundp 'consult--tofu-strip))
                         (consult--tofu-strip raw)
                       raw)))
      (when-let ((buffer (and buf-name (get-buffer buf-name))))
        ;; Save buffer name BEFORE killing — Emacs clears it on kill.
        ;; Kill the buffer without any prompts or confirmations.
        (with-current-buffer buffer
          (let ((kill-buffer-query-functions nil))
            (set-buffer-modified-p nil)
            (kill-buffer)))
        (if arg
            ;; C-u: close the minibuffer and re-run consult-buffer via a timer.
            (let ((input (minibuffer-contents)))
              (abort-recursive-edit)
              (run-with-idle-timer 0.01 nil
                (lambda ()
                  (let ((consult--buffer-history (list input)))
                    (consult-buffer)))))
          ;; C-d: keep the minibuffer open.  Scan vertico's candidate list
          ;; and drop every entry whose tofu-stripped name matches the
          ;; killed buffer.  The same buffer can live in multiple consult
          ;; sources ("Previous", "Eat", etc.), each with a different
          ;; source-index tofu — matching by name catches all of them.
          (let ((remaining nil))
            (dolist (c vertico--candidates)
              (unless (string= (substring-no-properties
                                (if (fboundp 'consult--tofu-strip)
                                    (consult--tofu-strip c)
                                  c))
                               buf-name)
                (push c remaining)))
            (setq vertico--candidates (nreverse remaining)
                  vertico--total (length vertico--candidates))
            ;; Adjust index: last candidate gone → prompt (-1);
            ;; otherwise clamp to valid position.
            (if (zerop vertico--total)
                (setq vertico--index -1)
              (when (>= vertico--index vertico--total)
                (setq vertico--index (max 0 (1- vertico--total)))))
            ;; Re-render the vertico list directly
            (vertico--prompt-selection)
            (vertico--display-count)
            (vertico--display-candidates (vertico--arrange-candidates)))))))

  ;; Bind C-d in vertico-map (active during all Vertico completion sessions,
  ;; including consult-buffer). The function safely ignores non-buffer
  ;; candidates like files and bookmarks.
  (keymap-set vertico-map "C-d" #'my/consult-kill-buffer))

;; ── Zoxide embark actions ──────────────────────────────────────
;; + and - work inside the zoxide consult minibuffer to adjust scores.

(defun embark-zoxide-add (candidate)
  "Boost the score of the selected zoxide directory by `zoxide-add-amount'.
Runs `zoxide add --score <amount>' to increment its frecency."
  (interactive)
  (zoxide-run nil "add" "--score" (number-to-string zoxide-add-amount) candidate)
  (embark--restart))

(defun embark-zoxide-subtract (candidate)
  "Demote the selected zoxide directory by `zoxide-subtract-amount'.
Parses the current score, removes the entry, then re-adds it
with a reduced score of `max(1, current - zoxide-subtract-amount)'."
  (interactive)
  (let* ((raw (zoxide-run nil "query" "-ls" candidate))
         (first-line (car (split-string raw "\n" t)))
         (current-score (and first-line
                             (car (zoxide-parse-score-line first-line))))
         (new-score (max 1 (- (or current-score 1)
                              zoxide-subtract-amount))))
    (zoxide-run nil "remove" candidate)
    (zoxide-run nil "add" "--score" (number-to-string new-score) candidate)
    (message "Zoxide: %s score reduced from %s to %s"
             candidate (or current-score "?") new-score))
  (embark--restart))

(defvar-keymap embark-zoxide-path-map
  :doc "Keymap for embark actions on zoxide-path candidates."
  :parent embark-general-map
  "+" #'embark-zoxide-add
  "-" #'embark-zoxide-subtract)

(add-to-list 'embark-keymap-alist '(zoxide-path . embark-zoxide-path-map))

(provide 'embark)
;; embark.el ends here
