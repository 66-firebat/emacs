;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  ghostfire.el — Ghostel terminal emulator configuration for Firemacs
;;
;;  Replaces eat/eaterz.el.  Features:
;;    - Indexed terminal spawning ("N   PID")
;;    - Mode-aware M-t dispatcher (grease → root dir, kill grease after)
;;    - Zoxide directory travel via consult + embark (formerly "eaterz")
;;    - Compose buffer (full Emacs editing → send to terminal)
;;    - Semi-char non-bound keys
;;    - Evil integration via evil-ghostel
;;
;;  Dependencies:
;;    ghostel (MELPA), evil-ghostel (MELPA), consult, embark, vertico, zoxide
;; =============================================================================

(require 'cl-lib)

;; ════════════════════════════════════════════════════════════════════════════
;; ── Core ghostel configuration ─────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════

(use-package ghostel
  :ensure t
  :defer t
  :custom
  (ghostel-shell-integration t)        ;; auto-inject shell integration (OSC 7, OSC 133)
  (ghostel-scrollback-size nil)        ;; unlimited scrollback (like eat)
  (ghostel-initial-input-mode 'semi-char)) ;; same default input mode as eat

;; Evil-mode integration — synchronises terminal cursor with Emacs point
;; so normal-mode hjkl navigation works correctly in ghostel buffers.
(use-package evil-ghostel
  :ensure t
  :defer t
  :after (ghostel evil)
  :hook (ghostel-mode . evil-ghostel-mode))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Indexed Terminal Spawning (M-t) ─────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════
;; Buffers are named "<index>   <PID>" (e.g., "1   19950").  The lowest
;; free index is reused first.  Bound to M-t in keybinds.el.

(defun my/ghostel-next-available ()
  "Return the lowest unused ghostel index (1, 2, 3, ...).
Scans all buffer names for \"<N> \" prefixes."
  (let ((i 1))
    (while (let ((target (format "%d " i)))
             (catch 'exists
               (dolist (b (buffer-list) nil)
                 (when (string-prefix-p target (buffer-name b))
                   (throw 'exists t)))))
      (setq i (1+ i)))
    i))

(defun my/ghostel-new (&optional dir)
  "Spawn a new ghostel terminal at the lowest available index.
Buffer is named like \"1  19950\" (index +  + PID).

The shell starts in `default-directory', or in DIR when DIR names an
existing directory.  If DIR is a file, its parent directory is used.
If DIR is nil or does not exist, `default-directory' is used silently."
  (interactive)
  (let* ((index (my/ghostel-next-available))
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
    ;; Bind default-directory (CWD) and ghostel-buffer-name (base name).
    ;; (ghostel t) = always fresh buffer (skips existence check).
    ;; Verified from source: ghostel.el L5293.
    (let ((default-directory cwd)
          (ghostel-buffer-name (format "%d " index)))
      (ghostel t))
    ;; Now we are in the ghostel buffer — rename to include our index + PID.
    (when-let* ((proc (and (boundp 'ghostel--process)
                           ghostel--process))
                ((process-live-p proc)))
      (rename-buffer (format "%d  %d" index (process-id proc))))
    (current-buffer)))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Dispatch — Mode-aware terminal spawning ─────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════
;; When M-t is pressed, the dispatcher checks the current buffer's mode
;; against `my/ghostel-new-dispatch-alist' and calls the associated handler.
;; If no match, falls through to `my/ghostel-new'.

(defvar my/ghostel-new-dispatch-alist
  '((grease-mode . my/ghostel-new-from-grease))
  "Alist mapping major-mode symbols to ghostel-spawn handler functions.
Each handler is called with no arguments and should call `my/ghostel-new'
with an appropriate directory (or no argument for `default-directory').
The dispatcher uses `derived-mode-p', so entries match any mode derived
from the key symbol.")

(defcustom my/ghostel-kill-grease-on-spawn t
  "When non-nil, kill the grease buffer after spawning a ghostel terminal from it.
If nil, the grease buffer is left alive (buried behind the ghostel buffer)."
  :type 'boolean
  :group 'ghostel)

(defun my/ghostel-new-from-grease ()
  "Spawn ghostel in the root directory of the current grease buffer.
Saves any pending grease changes via `grease-save-all-buffers',
which handles its own prompts.  If the user cancels the save,
`user-error' is signaled and no ghostel buffer is created.
Falls back to `default-directory' when `grease--root-dir' is nil.
If grease is not loaded, warns and falls through to `my/ghostel-new'.
When `my/ghostel-kill-grease-on-spawn' is non-nil, kills the grease
buffer after spawning to prevent clutter."
  (if (featurep 'grease)
      (let ((grease-buf (current-buffer)))
        (when (fboundp 'grease-save-all-buffers)
          (with-current-buffer grease-buf
            (grease-save-all-buffers)))
        (my/ghostel-new grease--root-dir)
        (when (and my/ghostel-kill-grease-on-spawn
                   (buffer-live-p grease-buf))
          (kill-buffer grease-buf)))
    (display-warning
     'ghostel
     (concat "grease-mode detected but grease.el is not loaded; "
             "spawning in default-directory")
     :warning)
    (my/ghostel-new)))

(defun my/ghostel-new-dispatch ()
  "Spawn a new ghostel terminal, mode-aware.
When the current buffer uses a mode listed in `my/ghostel-new-dispatch-alist',
calls the associated handler.  Otherwise falls through to `my/ghostel-new'
with no argument (uses `default-directory')."
  (interactive)
  (if-let ((handler (cdr (cl-assoc major-mode my/ghostel-new-dispatch-alist
                                   :test (lambda (_mode key)
                                           (derived-mode-p key))))))
      (funcall handler)
    (my/ghostel-new)))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Ghostel buffer list helpers ─────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════
;; Used by consult-buffer.el and keybinds.el.

(defun my/ghostel-buffer-list ()
  "Return all ghostel-mode buffers."
  (seq-filter (lambda (b)
                (with-current-buffer b (derived-mode-p 'ghostel-mode)))
              (buffer-list)))

(defun my/ghostel-spawn-at-index (index)
  "Create a new ghostel buffer with the given INDEX and return it.
Used by consult-buffer.el to spawn terminals from numeric input."
  (let* ((cwd default-directory)
         (ghostel-buffer-name (format "%d " index)))
    (let ((default-directory cwd))
      (ghostel t))  ;; t = always fresh buffer
    (when-let* ((proc (and (boundp 'ghostel--process)
                           ghostel--process))
                ((process-live-p proc)))
      (rename-buffer (format "%d  %d" index (process-id proc))))
    (current-buffer)))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Ghostfire — Zoxide travel for ghostel terminals ─────────────────────────
;; ════════════════════════════════════════════════════════════════════════════
;; Self-contained zoxide + consult + embark pipeline for directory jumping
;; inside ghostel terminal buffers (formerly "eaterz").  Bound to M-z via
;; `my/zoxide-travel-dispatch' in keybinds.el.
;; Does NOT depend on `zoxide.el' or `greaszy.el'.

;; ── Dependency guard ──────────────────────────────────────────────────────

(defun ghostfire--check-deps ()
  "Signal `user-error' if any required dependency for `ghostfire-travel' is missing."
  (unless ghostfire--executable
    (user-error "Ghostfire: `zoxide' binary not found on exec-path"))
  (unless (fboundp 'consult--read)
    (user-error "Ghostfire: consult is required — install it with `M-x package-install RET consult RET'"))
  (unless (featurep 'embark)
    (user-error "Ghostfire: embark is required — install it with `M-x package-install RET embark RET'"))
  (unless (featurep 'vertico)
    (user-error "Ghostfire: vertico is required — install it with `M-x package-install RET vertico RET'"))
  t)

;; ── Customization ─────────────────────────────────────────────────────────

(defcustom ghostfire-show-scores t
  "When non-nil, display the frecency score to the left of each path.
When nil, only the path is shown (scores are still used for ranking)."
  :type 'boolean
  :group 'ghostel)

(defcustom ghostfire-score-width 6
  "Width of the score field when displaying ghostfire results.
The score is right-justified within this width."
  :type 'integer
  :group 'ghostel)

(defcustom ghostfire-score-path-padding 4
  "Spaces between the score and the path in ghostfire results."
  :type 'integer
  :group 'ghostel)

(defcustom ghostfire-add-amount 5
  "Amount added to a directory's score on `ghostfire-embark-add'.
Passed as `--score' to `zoxide add'."
  :type 'integer
  :group 'ghostel)

(defcustom ghostfire-subtract-amount 5
  "Fixed amount subtracted on `ghostfire-embark-subtract'.
The directory is removed completely from zoxide (zoxide has no
native decrement operation)."
  :type 'integer
  :group 'ghostel)

;; ── Faces ─────────────────────────────────────────────────────────────────

(defface ghostfire-score-face
  '((t (:inherit font-lock-comment-face)))
  "Face for the frecency score in ghostfire results."
  :group 'ghostel)

;; ── Zoxide executable ─────────────────────────────────────────────────────

(defvar ghostfire--executable (executable-find "zoxide")
  "Cached path to the `zoxide' binary, set at load time.")

;; ── Zoxide process ────────────────────────────────────────────────────────

(defun ghostfire--run (async &rest args)
  "Run the `zoxide' command with ARGS.
If ASYNC is non-nil, launch asynchronously and return the process object.
Otherwise run synchronously and return stdout as a string, or nil on failure."
  (if async
      (apply #'start-process "ghostfire" "*ghostfire*" ghostfire--executable args)
    (with-temp-buffer
      (if (equal 0 (apply #'call-process ghostfire--executable nil t nil args))
          (buffer-string)
        (append-to-buffer "*ghostfire*" (point-min) (point-max))
        (warn "Ghostfire: zoxide error (see buffer *ghostfire* for details)")
        nil))))

;; ── Score parsing & display ─────────────────────────────────────────────

(defun ghostfire-parse-score-line (line)
  "Parse a single LINE from `zoxide query -ls' into (SCORE . PATH)."
  (let ((trimmed (string-trim line)))
    (when (string-match (rx (group (+ (or digit ?.)))
                            " "
                            (group (+ any)))
                        trimmed)
      (cons (string-to-number (match-string 1 trimmed))
            (string-trim (match-string 2 trimmed))))))

(defun ghostfire-format-entry (score path &optional score-width padding)
  "Format a ghostfire entry with SCORE right-justified before PATH.
When `ghostfire-show-scores' is nil, only the path is returned.
SCORE-WIDTH controls the score field width (default `ghostfire-score-width').
PADDING is the number of spaces between score and path."
  (if (not ghostfire-show-scores)
      path
    (let* ((sw (or score-width ghostfire-score-width))
           (pad (or padding ghostfire-score-path-padding))
           (score-str (format (format "%%%d.1f" sw) score)))
      (concat
       (propertize score-str 'face 'ghostfire-score-face)
       (make-string pad ?\s)
       path))))

(defun ghostfire-consult-format (line)
  "Format a raw LINE from `zoxide query -ls' for consult display.
Returns a propertized string with `ghostfire-score' and `ghostfire-path'
text properties, or nil if LINE can't be parsed."
  (pcase (ghostfire-parse-score-line line)
    (`(,score . ,path)
     (propertize (ghostfire-format-entry score path)
                 'ghostfire-score score
                 'ghostfire-path path))
    (_ nil)))

(defun ghostfire-consult-builder (input)
  "Build command line for `zoxide query -ls' from INPUT.
Returns a command list or nil.
Splits INPUT on whitespace for multi-keyword matching."
  (if (or (not input) (string-empty-p input))
      (list ghostfire--executable "query" "-ls")
    (apply #'list ghostfire--executable "query" "-ls" (split-string input))))

;; ── Consult async pipeline ────────────────────────────────────────────────

(defun ghostfire--async-wrap (async)
  "Wrap ASYNC function for ghostfire consult pipeline.
Adds an indicator spinner and refresh-on-input behaviour via
`consult--async-pipeline'."
  (consult--async-pipeline
   async
   (consult--async-indicator)
   (consult--async-refresh)))

;; ── Keymap ────────────────────────────────────────────────────────────────

(defvar-keymap ghostfire-consult-map
  :doc "Additional keybindings for the ghostfire travel minibuffer.
C-i boosts the frecency score of the selected directory.
C-d removes the selected directory from zoxide."
  "C-i" #'ghostfire-embark-add
  "C-d" #'ghostfire-embark-subtract)

;; ── Embark actions ────────────────────────────────────────────────────────

(defun ghostfire--embark-extract-path (&optional candidate)
  "Extract the path from a vertico candidate.
If CANDIDATE is provided, strip its score prefix.  Otherwise read from
`vertico--candidate', tofu-strip, and parse."
  (unless candidate
    (setq candidate (vertico--candidate))
    (when (and candidate (fboundp 'consult--tofu-strip))
      (setq candidate (consult--tofu-strip candidate))))
  (or (cdr (ghostfire-parse-score-line candidate)) candidate))

(defun ghostfire--embark-refresh ()
  "Re-query zoxide and replace `vertico--candidates' in place.
Uses the current minibuffer input as the query filter."
  (let* ((input (minibuffer-contents-no-properties))
         (args (if (or (not input) (string-empty-p input))
                   '("query" "-ls")
                 `("query" "-ls" ,input)))
         (raw (apply #'ghostfire--run nil args))
         (lines (and raw (remove "" (split-string raw "\n" t))))
         (new-candidates (delq nil (mapcar #'ghostfire-consult-format lines))))
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

(defun ghostfire-embark-add (&optional candidate)
  "Boost the frecency score of the selected zoxide directory.
Runs `zoxide add --score N <path>' where N is `ghostfire-add-amount'."
  (interactive)
  (setq candidate (ghostfire--embark-extract-path candidate))
  (when candidate
    (ghostfire--run nil "add" "--score"
                    (number-to-string ghostfire-add-amount) candidate)
    (ghostfire--embark-refresh)
    (message "Ghostfire: %s +%d" candidate ghostfire-add-amount))
  candidate)

(defun ghostfire-embark-subtract (&optional candidate)
  "Remove the selected directory from the zoxide database.
Runs `zoxide remove <path>'.  Note: zoxide does not support a native
'decrement' operation, so the entry is fully removed."
  (interactive)
  (setq candidate (ghostfire--embark-extract-path candidate))
  (when candidate
    (ghostfire--run nil "remove" candidate)
    (ghostfire--embark-refresh)
    (message "Ghostfire: %s removed" candidate))
  candidate)

;; ── Embark keymap registration ────────────────────────────────────────────

(with-eval-after-load 'embark
  (defvar-keymap ghostfire-embark-path-map
    :doc "Keymap for embark actions on ghostfire-path candidates."
    :parent embark-general-map
    "+" #'ghostfire-embark-add
    "-" #'ghostfire-embark-subtract)

  (add-to-list 'embark-keymap-alist '(ghostfire-path . ghostfire-embark-path-map)))

;; ── Main entry point ──────────────────────────────────────────────────────

(defun ghostfire-travel ()
  "Select a zoxide directory and cd to it in the current ghostel terminal.
Queries the zoxide database via consult's async completion, showing
frecency scores.  On selection, sends `cd <dir> && clear' to the
shell process of the current ghostel terminal.

Requires consult, embark, and vertico.  The `zoxide' binary must be
on `exec-path'.  Signals `user-error' if any dependency is missing.

This function assumes the caller has already verified we are in a
ghostel terminal buffer (the dispatcher guarantees this)."
  (interactive)
  (ghostfire--check-deps)
  (let* ((origin-buffer (current-buffer))
         (candidate
          (consult--read
           (consult--process-collection #'ghostfire-consult-builder
             :transform (consult--async-map #'ghostfire-consult-format))
           :async-wrap #'ghostfire--async-wrap
           :keymap ghostfire-consult-map
           :prompt "󰡦 : "
           :category 'ghostfire-path
           :require-match t
           :sort nil
           :lookup (lambda (selected &rest _)
                     (when selected
                       (or (cdr (ghostfire-parse-score-line selected))
                           selected))))))
    (when (and candidate (buffer-live-p origin-buffer))
      (with-current-buffer origin-buffer
        (if (and (boundp 'ghostel--process) ghostel--process
                 (process-live-p ghostel--process))
            (progn
              (ghostel-send-string (format "cd %s && clear\n" candidate))
              (message "Ghostfire: cd to %s" candidate))
          (user-error "Ghostfire: no active process in this ghostel terminal"))))
    candidate))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Compose Buffer ──────────────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════
;; Full Emacs buffer for typing into ghostel.  C-c C-c sends, C-c C-k cancels.

(defvar-local my/ghostel-compose-source nil
  "Buffer of the ghostel terminal this compose buffer belongs to.")

(define-minor-mode my/ghostel-compose-mode
  "Minor mode for composing text to send to a ghostel terminal.

Keybindings:
  C-c C-c  — Send text to ghostel and close
  C-c C-k  — Cancel and close"
  :lighter " "
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-c") 'my/ghostel-compose-send)
            (define-key map (kbd "C-c C-k") 'my/ghostel-compose-cancel)
            map)
  (when my/ghostel-compose-mode
    (setq header-line-format
          " Compose text — C-c C-c to send, C-c C-k to cancel")))

(defun my/ghostel-compose ()
  "Open a compose buffer to write text for the current ghostel terminal.
If called from a visual selection, captures the selected text into
the compose buffer.  Otherwise starts empty.

Type your text with full Emacs editing, then:
  C-c C-c  — Send to ghostel and close
  C-c C-k  — Cancel and close"
  (interactive)
  (unless (derived-mode-p 'ghostel-mode)
    (user-error "Not in a ghostel terminal buffer"))
  (let* ((source-buf (current-buffer))
         (selected (when (and (fboundp 'evil-visual-state-p)
                              (evil-visual-state-p))
                     (buffer-substring-no-properties
                      (region-beginning) (region-end)))))
    (switch-to-buffer (get-buffer-create "*ghostel-compose*"))
    (unless (zerop (buffer-size))
      (erase-buffer))
    (when selected
      (insert selected))
    (text-mode)
    (setq my/ghostel-compose-source source-buf)
    (my/ghostel-compose-mode 1)
    ;; Start in insert state: type immediately, ESC to use evil nav
    (when (fboundp 'evil-insert-state)
      (evil-insert-state))))

(defun my/ghostel-compose-send ()
  "Send the compose buffer text to the ghostel terminal and close."
  (interactive)
  (let* ((new-text (buffer-string))
         ;; Clear existing shell input (C-u in readline) then insert new text
         (text (concat "\C-u" new-text "\n"))
         (source my/ghostel-compose-source)
         (compose-buf (current-buffer)))
    ;; Switch to ghostel buffer and send
    (when (buffer-live-p source)
      (switch-to-buffer source)
      (when (and (derived-mode-p 'ghostel-mode)
                 (fboundp 'ghostel-send-string))
        (ghostel-send-string text))
      (when (fboundp 'evil-normal-state)
        (evil-normal-state)))
    ;; Clean up compose buffer
    (when (buffer-live-p compose-buf)
      (kill-buffer compose-buf))))

(defun my/ghostel-compose-cancel ()
  "Cancel composing and close the buffer."
  (interactive)
  (let ((source my/ghostel-compose-source))
    (if (and source (buffer-live-p source))
        (switch-to-buffer source)
      (switch-to-buffer (other-buffer)))
    (when (buffer-live-p (get-buffer "*ghostel-compose*"))
      (kill-buffer (get-buffer "*ghostel-compose*")))
    (when (fboundp 'evil-normal-state)
      (evil-normal-state))))

;; ════════════════════════════════════════════════════════════════════════════
;; ── Semi-char non-bound keys ────────────────────────────────────────────────
;; ════════════════════════════════════════════════════════════════════════════
;; Tell ghostel to ignore these Alt- chords in semi-char mode so Emacs can
;; handle them.  Same set as the old eat configuration.
;;
;; NOTE: ghostel-semi-char-non-bound-keys uses the same vector format as
;; eat-semi-char-non-bound-keys: [?\e ?<char>] for Alt + char, and ghostel's
;; semi-char mode is modelled on eat's.

(with-eval-after-load 'ghostel
  (when (boundp 'ghostel-semi-char-non-bound-keys)
    (dolist (key '(("M-t" . [?\e ?t])
                   ("M-r" . [?\e ?r])
                   ("M-k" . [?\e ?k])
                   ("M-g" . [?\e ?g])
                   ("M-i" . [?\e ?i])
                   ("M-z" . [?\e ?z])
                   ("M-w" . [?\e ?w])
                   ("M-W" . [?\e ?W])
                   ("M-e" . [?\e ?e])
                   ("M-h" . [?\e ?h])
                   ("M-l" . [?\e ?l])))
      (add-to-list 'ghostel-semi-char-non-bound-keys (cdr key))
      (when (boundp 'ghostel-semi-char-mode-map)
        (define-key ghostel-semi-char-mode-map (kbd (car key)) nil))
      (when (and (boundp 'ghostel--semi-char-mode-map)
                 (not (eq ghostel--semi-char-mode-map
                          (and (boundp 'ghostel-semi-char-mode-map)
                               ghostel-semi-char-mode-map))))
        (define-key ghostel--semi-char-mode-map (kbd (car key)) nil)))))

(provide 'ghostfire)
;; ghostfire.el ends here
