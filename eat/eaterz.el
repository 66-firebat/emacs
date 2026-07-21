;; -*- lexical-binding: t; -*-

(require 'cl-lib)

;; ── Terminal Width ──────────────────────────────────────────────────────────
;; eat-exec calls (eat-term-resize ... (window-max-chars-per-line) ...) which
;; sets the terminal too wide (130) — it doesn't account for statuscolumn's
;; 7-char line-prefix.  We advice eat-term-resize to detect this and subtract
;; the line-prefix width so the terminal is correct from the start.

(defun my/eat-adjust-window-size (process windows)
  "Return terminal size (WIDTH . HEIGHT) accounting for statuscolumn.
Used by window--adjust-process-windows for ongoing resize handling."
  (condition-case nil
      (let ((window (car windows)))
        (when (window-live-p window)
          (let* ((mcl (window-max-chars-per-line window))
                 (lp (buffer-local-value 'line-prefix (window-buffer window)))
                 (lpw (if (and (stringp lp) (> (length lp) 0))
                          (string-width lp) 0))
                 (tw (max (- mcl lpw) 1)))
            (cons tw (window-text-height window)))))
    (error nil)))

(defun my/eat-resize-correct-line-prefix (fn terminal width height)
  "When eat resizes to window-max-chars-per-line, subtract line-prefix."
  (let* ((buf (ignore-errors (eat--t-term-buffer terminal)))
         (corrected width))
    (when buf
      (let* ((win (get-buffer-window buf t))
             (mcl (and win (window-max-chars-per-line win)))
             (lp (buffer-local-value 'line-prefix buf))
             (lpw (if (and (stringp lp) (> (length lp) 0))
                      (string-width lp) 0)))
        ;; If this resize matches the uncorrected window width,
        ;; subtract the line-prefix to account for the statuscolumn.
        (when (and mcl (> lpw 0) (= width mcl))
          (setq corrected (max (- width lpw) 1)))))
    (funcall fn terminal corrected height)))

;; ── use-package ─────────────────────────────────────────────────────────────

(use-package eat
  :ensure t
  :config
  (setq eat-enable-shell-integration t)
  (setq eat-default-input-mode 'semi-char)
  (setq eat-enable-shell-prompt-annotation nil)
  (setq eat-term-scrollback-size nil)

  (add-hook 'eat-mode-hook
            (lambda ()
              (setq-local window-adjust-process-window-size-function
                          #'my/eat-adjust-window-size)))

  (defun my/eat-snap-cursor-on-insert ()
    (when (and (derived-mode-p 'eat-mode) (bound-and-true-p eat-terminal))
      (let ((pos (ignore-errors (eat-term-display-cursor eat-terminal))))
        (when (and pos (<= (point-min) pos (point-max)) (/= pos (point)))
          (goto-char pos)))))
  (add-hook 'evil-insert-state-entry-hook #'my/eat-snap-cursor-on-insert))

;; ── Advice ──────────────────────────────────────────────────────────────────
;; Fix initial terminal width by intercepting eat-term-resize
(advice-add 'eat-term-resize :around #'my/eat-resize-correct-line-prefix)

;; ── Spawn Terminal (M-t) ─────────────────────────────────────────────────────
;; Indexed eat sessions: buffers are named "<index>  <PID>" and the lowest
;; free index is reused first.  Bound to M-t in keybinds.el.

(defun my/eat-next-available ()
  "Return the lowest unused eat index (1, 2, 3, ...).
Scans all buffer names for \"<N> \" prefixes."
  (let ((i 1))
    (while (let ((target (format "%d " i)))
             (catch 'exists
               (dolist (b (buffer-list) nil)
                 (when (string-prefix-p target (buffer-name b))
                   (throw 'exists t)))))
      (setq i (1+ i)))
    i))

(defun my/eat-new (&optional dir)
  "Spawn a new eat terminal at the lowest available index.
Buffer is named like \"1  19950\" (index +  + PID).

The shell starts in `default-directory', or in DIR when DIR names an
existing directory.  If DIR is a file, its parent directory is used.
If DIR is nil or does not exist, `default-directory' is used silently."
  (interactive)
  (let* ((index (my/eat-next-available))
         (shell (or explicit-shell-file-name
                    (getenv "ESHELL")
                    shell-file-name))
         (cwd (cond
               ((and dir
                     (let ((expanded (expand-file-name dir)))
                       (cond
                        ((file-directory-p expanded)
                         (file-name-as-directory expanded))
                        ((file-exists-p expanded)
                         (file-name-directory expanded))
                        (t nil)))))
               (t default-directory))))
    (let ((buf-name (format "%d  waiting" index)))
      (with-current-buffer (get-buffer-create buf-name)
        (setq default-directory cwd)
        (eat-mode)
        (pop-to-buffer-same-window (current-buffer))
        (unless (and eat-terminal
                     (eat-term-parameter eat-terminal 'eat--process))
          (eat-exec (current-buffer) (buffer-name)
                    "/usr/bin/env" nil
                    (list "sh" "-c" shell)))
        ;; Rename buffer to include the PID
        (when-let* ((proc (eat-term-parameter eat-terminal 'eat--process))
                    ((process-live-p proc)))
          (rename-buffer (format "%d  %d" index (process-id proc))))
        (current-buffer)))))

;; ── Dispatch ────────────────────────────────────────────────────────────────
;; Mode-aware terminal spawning: when M-t is pressed, the dispatcher checks
;; the current buffer's mode against `my/eat-new-dispatch-alist' and calls
;; the associated handler.  If no match, falls through to `my/eat-new'.

(defvar my/eat-new-dispatch-alist
  '((grease-mode . my/eat-new-from-grease))
  "Alist mapping major-mode symbols to eat-spawn handler functions.
Each handler is called with no arguments and should call `my/eat-new'
with an appropriate directory (or no argument for `default-directory').
The dispatcher uses `derived-mode-p', so entries match any mode derived
from the key symbol.")

(defcustom my/eat-kill-grease-on-spawn t
  "When non-nil, kill the grease buffer after spawning an eat terminal from it.
If nil, the grease buffer is left alive (buried behind the eat buffer)."
  :type 'boolean
  :group 'eat)

(defun my/eat-new-from-grease ()
  "Spawn eat in the root directory of the current grease buffer.
Saves any pending grease changes via `grease-save-all-buffers',
which handles its own prompts.  If the user cancels the save,
`user-error' is signaled and no eat buffer is created.
Falls back to `default-directory' when `grease--root-dir' is nil.
If grease is not loaded, warns and falls through to `my/eat-new'.
When `my/eat-kill-grease-on-spawn' is non-nil, kills the grease
buffer after spawning to prevent clutter."
  (if (featurep 'grease)
      (let ((grease-buf (current-buffer)))
        (when (fboundp 'grease-save-all-buffers)
          (with-current-buffer grease-buf
            (grease-save-all-buffers)))
        (my/eat-new grease--root-dir)
        (when (and my/eat-kill-grease-on-spawn
                   (buffer-live-p grease-buf))
          (kill-buffer grease-buf)))
    (display-warning
     'eat
     (concat "grease-mode detected but grease.el is not loaded; "
             "spawning in default-directory")
     :warning)
    (my/eat-new)))

(defun my/eat-new-dispatch ()
  "Spawn a new eat terminal, mode-aware.
When the current buffer uses a mode listed in `my/eat-new-dispatch-alist',
calls the associated handler.  Otherwise falls through to `my/eat-new'
with no argument (uses `default-directory')."
  (interactive)
  (if-let ((handler (cdr (cl-assoc major-mode my/eat-new-dispatch-alist
                                   :test #'derived-mode-p))))
      (funcall handler)
    (my/eat-new)))

;; ── Eaterz ── Zoxide travel for eat terminals ──────────────────────────────
;; Self-contained zoxide + consult + embark pipeline for directory jumping
;; inside eat terminal buffers.  Bound to M-z via `my/zoxide-travel-dispatch'
;; in keybinds.el.  Does NOT depend on `zoxide.el' or `greaszy.el'.

;; ════════════════════════════════════════════════════════════════════════════
;; ── Dependency guard ───────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defun eaterz--check-deps ()
  "Signal `user-error' if any required dependency for `eaterz-travel' is missing."
  (unless eaterz--executable
    (user-error "Eaterz: `zoxide' binary not found on exec-path"))
  (unless (fboundp 'consult--read)
    (user-error "Eaterz: consult is required — install it with `M-x package-install RET consult RET'"))
  (unless (featurep 'embark)
    (user-error "Eaterz: embark is required — install it with `M-x package-install RET embark RET'"))
  (unless (featurep 'vertico)
    (user-error "Eaterz: vertico is required — install it with `M-x package-install RET vertico RET'"))
  t)

;; ════════════════════════════════════════════════════════════════════════════
;; ── Customization ──────────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defcustom eaterz-show-scores t
  "When non-nil, display the frecency score to the left of each path.
When nil, only the path is shown (scores are still used for ranking)."
  :type 'boolean
  :group 'eat)

(defcustom eaterz-score-width 6
  "Width of the score field when displaying eaterz results.
The score is right-justified within this width."
  :type 'integer
  :group 'eat)

(defcustom eaterz-score-path-padding 4
  "Spaces between the score and the path in eaterz results."
  :type 'integer
  :group 'eat)

(defcustom eaterz-add-amount 5
  "Amount added to a directory's score on `eaterz-embark-add'.
Passed as `--score' to `zoxide add'."
  :type 'integer
  :group 'eat)

(defcustom eaterz-subtract-amount 5
  "Fixed amount subtracted on `eaterz-embark-subtract'.
The directory is removed and re-added at `max(1, current - this)'."
  :type 'integer
  :group 'eat)

;; ════════════════════════════════════════════════════════════════════════════
;; ── Faces ──────────────────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defface eaterz-score-face
  '((t (:inherit font-lock-comment-face)))
  "Face for the frecency score in eaterz results."
  :group 'eat)

;; ════════════════════════════════════════════════════════════════════════════
;; ── Zoxide executable ──────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defvar eaterz--executable (executable-find "zoxide")
  "Cached path to the `zoxide' binary, set at load time.")

;; ════════════════════════════════════════════════════════════════════════════
;; ── Zoxide process ─────────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defun eaterz--run (async &rest args)
  "Run the `zoxide' command with ARGS.
If ASYNC is non-nil, launch asynchronously and return the process object.
Otherwise run synchronously and return stdout as a string, or nil on failure."
  (if async
      (apply #'start-process "eaterz" "*eaterz*" eaterz--executable args)
    (with-temp-buffer
      (if (equal 0 (apply #'call-process eaterz--executable nil t nil args))
          (buffer-string)
        (append-to-buffer "*eaterz*" (point-min) (point-max))
        (warn "Eaterz: zoxide error (see buffer *eaterz* for details)")
        nil))))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Score parsing & display ────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defun eaterz-parse-score-line (line)
  "Parse a single LINE from `zoxide query -ls' into (SCORE . PATH)."
  (let ((trimmed (string-trim line)))
    (when (string-match (rx (group (+ (or digit ?.)))
                            " "
                            (group (+ any)))
                        trimmed)
      (cons (string-to-number (match-string 1 trimmed))
            (string-trim (match-string 2 trimmed))))))

(defun eaterz-format-entry (score path &optional score-width padding)
  "Format an eaterz entry with SCORE right-justified before PATH.
When `eaterz-show-scores' is nil, only the path is returned.
SCORE-WIDTH controls the score field width (default `eaterz-score-width').
PADDING is the number of spaces between score and path."
  (if (not eaterz-show-scores)
      path
    (let* ((sw (or score-width eaterz-score-width))
           (pad (or padding eaterz-score-path-padding))
           (score-str (format (format "%%%d.1f" sw) score)))
      (concat
       (propertize score-str 'face 'eaterz-score-face)
       (make-string pad ?\s)
       path))))

(defun eaterz-consult-format (line)
  "Format a raw LINE from `zoxide query -ls' for consult display.
Returns a propertized string with `eaterz-score' and `eaterz-path'
text properties, or nil if LINE can't be parsed."
  (pcase (eaterz-parse-score-line line)
    (`(,score . ,path)
     (propertize (eaterz-format-entry score path)
                 'eaterz-score score
                 'eaterz-path path))
    (_ nil)))

(defun eaterz-consult-builder (input)
  "Build command line for `zoxide query -ls' from INPUT.
Returns a command list or nil."
  (if (or (not input) (string-empty-p input))
      (list eaterz--executable "query" "-ls")
    (list eaterz--executable "query" "-ls" input)))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Consult async pipeline ─────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defun eaterz--async-wrap (async)
  "Wrap ASYNC function for eaterz consult pipeline.
Adds an indicator spinner and refresh-on-input behaviour via
`consult--async-pipeline'."
  (consult--async-pipeline
   async
   (consult--async-indicator)
   (consult--async-refresh)))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Keymap ─────────────────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defvar-keymap eaterz-consult-map
  :doc "Additional keybindings for the eaterz travel minibuffer.
C-i boosts the frecency score of the selected directory.
C-d removes the selected directory from zoxide."
  "C-i" #'eaterz-embark-add
  "C-d" #'eaterz-embark-subtract)

;; ════════════════════════════════════════════════════════════════════════════
;; ── Embark actions ─────────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defun eaterz--embark-extract-path (&optional candidate)
  "Extract the path from a vertico candidate.
If CANDIDATE is provided, strip its score prefix.  Otherwise read from
`vertico--candidate', tofu-strip, and parse."
  (unless candidate
    (setq candidate (vertico--candidate))
    (when (and candidate (fboundp 'consult--tofu-strip))
      (setq candidate (consult--tofu-strip candidate))))
  (or (cdr (eaterz-parse-score-line candidate)) candidate))

(defun eaterz--embark-refresh ()
  "Re-query zoxide and replace `vertico--candidates' in place.
Uses the current minibuffer input as the query filter."
  (let* ((input (minibuffer-contents-no-properties))
         (args (if (or (not input) (string-empty-p input))
                   '("query" "-ls")
                 `("query" "-ls" ,input)))
         (raw (apply #'eaterz--run nil args))
         (lines (and raw (remove "" (split-string raw "\n" t))))
         (new-candidates (delq nil (mapcar #'eaterz-consult-format lines))))
    (when (and (boundp 'vertico--candidates) vertico--candidates)
      (setq vertico--candidates new-candidates
            vertico--total (length vertico--candidates))
      (if (zerop vertico--total)
          (setq vertico--index -1)
        (when (>= vertico--index vertico--total)
          (setq vertico--index (max 0 (1- vertico--total)))))
      (vertico--prompt-selection)
      (vertico--display-count)
      (vertico--display-candidates (vertico--arrange-candidates)))))

(defun eaterz-embark-add (&optional candidate)
  "Boost the frecency score of the selected zoxide directory.
Runs `zoxide add --score N <path>' where N is `eaterz-add-amount'."
  (interactive)
  (setq candidate (eaterz--embark-extract-path candidate))
  (when candidate
    (eaterz--run nil "add" "--score"
                 (number-to-string eaterz-add-amount) candidate)
    (eaterz--embark-refresh)
    (message "Eaterz: %s +%d" candidate eaterz-add-amount))
  candidate)

(defun eaterz-embark-subtract (&optional candidate)
  "Remove the selected directory from the zoxide database.
Runs `zoxide remove <path>'.  Note: zoxide does not support a native
'decrement' operation, so the entry is fully removed."
  (interactive)
  (setq candidate (eaterz--embark-extract-path candidate))
  (when candidate
    (eaterz--run nil "remove" candidate)
    (eaterz--embark-refresh)
    (message "Eaterz: %s removed" candidate))
  candidate)

;; ════════════════════════════════════════════════════════════════════════════
;; ── Embark keymap registration ─────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(with-eval-after-load 'embark
  (defvar-keymap eaterz-embark-path-map
    :doc "Keymap for embark actions on eaterz-path candidates."
    :parent embark-general-map
    "+" #'eaterz-embark-add
    "-" #'eaterz-embark-subtract)

  (add-to-list 'embark-keymap-alist '(eaterz-path . eaterz-embark-path-map)))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Main entry point ───────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(defun eaterz-travel ()
  "Select a zoxide directory and cd to it in the current eat terminal.
Queries the zoxide database via consult's async completion, showing
frecency scores.  On selection, sends `cd <dir> && clear' to the
shell process of the current eat terminal.

Requires consult, embark, and vertico.  The `zoxide' binary must be
on `exec-path'.  Signals `user-error' if any dependency is missing.

This function assumes the caller has already verified we are in an
eat terminal buffer (the dispatcher guarantees this)."
  (interactive)
  (eaterz--check-deps)
  (let* ((origin-buffer (current-buffer))
         (candidate
          (consult--read
           (consult--process-collection #'eaterz-consult-builder
             :transform (consult--async-map #'eaterz-consult-format))
           :async-wrap #'eaterz--async-wrap
           :keymap eaterz-consult-map
           :prompt "󰡦 : "
           :category 'eaterz-path
           :require-match t
           :sort nil
           :lookup (lambda (selected &rest _)
                     (when selected
                       (or (cdr (eaterz-parse-score-line selected))
                           selected))))))
    (when (and candidate (buffer-live-p origin-buffer))
      (with-current-buffer origin-buffer
        (if-let ((proc (eat-term-parameter eat-terminal 'eat--process)))
            (progn
              (eat--send-string proc (format "cd %s && clear\n" candidate))
              (message "Eaterz: cd to %s" candidate))
          (user-error "Eaterz: no active process in this eat terminal"))))
    candidate))


(provide 'eat-firemacs)
