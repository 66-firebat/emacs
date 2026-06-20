;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  keybinds.el — All custom keybindings
;;
;;  Every keybinding in the Emacs configuration lives here.
;;  The `leader` key is defined in init.el (general-create-definer).
;; =============================================================================

;; ── Window navigation (normal mode) ────────────────────────────
;; Ctrl + hjkl to move between windows, like Vim
(general-def 'normal
  "C-h" 'evil-window-left
  "C-j" 'evil-window-down
  "C-k" 'evil-window-up
  "C-l" 'evil-window-right)

;; ── Line motion (normal mode) ────────────────────────────────
;; Capital L/H for end/start of line (like $ and 0 in Vim).
;; Overrides Evil's default H/L (window-top/window-bottom).
(general-def '(normal visual visual-block visual-line)
  "L" 'evil-last-non-blank
  "H" 'evil-first-non-blank)

;; ── Avy — jump to any visible character ────────────────────────
;; s + one char  → jump to word starting with that char
;; S + two chars → jump to that exact character pair
;; g s           → jump to a visible line number
(general-def 'normal
  "s" 'avy-goto-word-1
  "S" 'avy-goto-char-2
  "gs" 'avy-goto-line)

;; ═════════════════════════════════════════════════════════════════
;;  SPC t t — Spawn Vterm
;; ═════════════════════════════════════════════════════════════════

(defvar my-vterm-counter -1
  "Index of the most recently spawned vterm via SPC t t.
Used as a hint, but my/vterm-new always picks the lowest free index.")

(defun my/vterm-next-available ()
  "Return the lowest unused vterm index (0, 1, 2, ...).
Scans all buffer names for \"vterm-<N>\" prefixes."
  (let ((i 0))
    (while (let ((target (format "%d " i)))
             (catch 'exists
               (dolist (b (buffer-list) nil)
                 (when (string-prefix-p target (buffer-name b))
                   (throw 'exists t)))))
      (setq i (1+ i)))
    i))

(defun my/vterm-new ()
  "Spawn a new vterm at the lowest available index."
  (interactive)
  (let ((index (my/vterm-next-available)))
    (setq my-vterm-counter index)
    (let ((buf-name (format "%d  waiting" index)))
      (vterm buf-name)
      (with-current-buffer buf-name
        (when (and (buffer-live-p (current-buffer))
                   vterm--process
                   (process-live-p vterm--process))
          (rename-buffer (format "%d  %d" index
                                  (process-id vterm--process))))))))

;; ═════════════════════════════════════════════════════════════════
;;  SPC b r — Previous Buffer
;; ═════════════════════════════════════════════════════════════════

(defun my/switch-to-other-buffer ()
  "Switch to the most recently viewed buffer.  Toggles A -> B -> A."
  (interactive)
  (let ((other (other-buffer (current-buffer) t)))
    (if other
        (switch-to-buffer other)
      (message "No previous buffer available"))))

;; ═════════════════════════════════════════════════════════════════
;;  SPC b 0-9 — Jump to buffer by index
;; ═════════════════════════════════════════════════════════════════

(defvar my/excluded-buffer-names '("*scratch*" "*Messages*")
  "Buffer names excluded from SPC b # navigation.")

(defvar my/excluded-buffer-modes '(vterm-mode)
  "Major modes excluded from SPC b # navigation.")

(defun my/filtered-buffer-list ()
  "Return buffer list excluding `my/excluded-buffer-names' and
`my/excluded-buffer-modes'."
  (delq nil
        (mapcar (lambda (b)
                  (with-current-buffer b
                    (unless (or (member (buffer-name) my/excluded-buffer-names)
                                (apply #'derived-mode-p my/excluded-buffer-modes))
                      b)))
                (buffer-list))))

(defun my/filtered-buffer-index-strings ()
  "Return numbered strings like \"3: README.md\" for SPC b completion."
  (let ((n 0))
    (mapcar (lambda (b)
              (prog1 (format "%d: %s" n (buffer-name b))
                (setq n (1+ n))))
            (my/filtered-buffer-list))))

;; ═════════════════════════════════════════════════════════════════
;;  SPC v 0-9 — Jump to / spawn vterm by index
;; ═════════════════════════════════════════════════════════════════

(defun my/vterm-buffer-list ()
  "Return all vterm-mode buffers."
  (seq-filter (lambda (b)
                (with-current-buffer b (derived-mode-p 'vterm-mode)))
              (buffer-list)))

(defun my/vterm-index-strings ()
  "Return index strings like \"7\" for all existing vterm buffers.
Sorted numerically."
  (let ((indices (delq nil
                       (mapcar (lambda (b)
                                 (let ((n (buffer-name b)))
                                   (when (string-match "\\`\\([0-9]+\\) " n)
                                                     (buffer-name b))
                                   (match-string 1 (buffer-name b))))
                               (my/vterm-buffer-list)))))
    (mapcar #'number-to-string
            (sort (mapcar #'string-to-number indices) #'<))))

(defun my/vterm-spawn-at-index (index)
  "Create a new vterm buffer with the given INDEX and return it."
  (let* ((buf-name (format "%d  waiting" index))
         (buf (vterm buf-name)))
    (with-current-buffer buf
      (when (and vterm--process (process-live-p vterm--process))
        (rename-buffer (format "%d  %d" index
                                (process-id vterm--process)))))
    buf))

;; ═════════════════════════════════════════════════════════════════
;;  Goto functions — called by digit keybindings below
;; ═════════════════════════════════════════════════════════════════

(defun my/vterm-goto ()
  "Jump to or spawn a vterm by index.  Pressed digit seeds the search."
  (interactive)
  (let* ((keys (this-single-command-keys))
         (key (aref keys (1- (length keys))))
         (initial (char-to-string key))
         (candidates (my/vterm-index-strings))
         (input (completing-read "vterm: " candidates nil nil initial)))
    (if (string= input "")
        (message "Cancelled")
      (let ((index (string-to-number input)))
        (if (member input candidates)
            (let ((buf (my/vterm-buffer-by-index index)))
              (if buf (switch-to-buffer buf)
                (my/vterm-spawn-at-index index)))
          (my/vterm-spawn-at-index index)
          (message "Spawned vterm %d" index))))))

(defun my/vterm-buffer-by-index (index)
  "Return the vterm buffer with the given INDEX, or nil."
  (car (seq-filter
        (lambda (b)
          (string-match-p (format "\\`%d " index) (buffer-name b)))
        (my/vterm-buffer-list))))

(defun my/buffer-goto ()
  "Jump to a non-excluded buffer by index.  Pressed digit seeds the search."
  (interactive)
  (let* ((keys (this-single-command-keys))
         (key (aref keys (1- (length keys))))
         (initial (char-to-string key))
         (candidates (my/filtered-buffer-index-strings))
         (input (completing-read "buffer: " candidates nil nil initial)))
    (unless (string= input "")
      (let* ((colon-pos (string-match ":" input))
             (index-str (if colon-pos (substring input 0 colon-pos) input))
             (index (string-to-number index-str))
             (bufs (my/filtered-buffer-list))
             (buf (nth index bufs)))
        (if buf
            (switch-to-buffer buf)
          (message "No buffer at index %d" index))))))

;; ═════════════════════════════════════════════════════════════════
;;  SPC leader keybindings
;; ═════════════════════════════════════════════════════════════════

(leader
  ;; Files
  "SPC" '(consult-buffer :which-key "switch buffer")
  "f f" '(find-file :which-key "find file")
  "f r" '(consult-recent-file :which-key "recent files")
  "f s" '(save-buffer :which-key "save buffer")

  ;; Buffers
  "k k" '(my/switch-to-other-buffer :which-key "previous buffer")
  "b d" '(kill-current-buffer :which-key "kill buffer")
  "b n" '(next-buffer :which-key "next buffer")
  "b p" '(previous-buffer :which-key "previous buffer")

  ;; Tabs
  "h" '(centaur-tabs-backward :which-key "prev tab")
  "l" '(centaur-tabs-forward :which-key "next tab")

  ;; Windows
  "w v" '(evil-window-vsplit :which-key "vertical split")
  "w s" '(evil-window-split :which-key "horizontal split")
  "w d" '(evil-window-delete :which-key "delete window")
  "w m" '(delete-other-windows :which-key "maximize window")
  "w h" '(evil-window-left :which-key "left window")
  "w j" '(evil-window-down :which-key "down window")
  "w k" '(evil-window-up :which-key "up window")
  "w l" '(evil-window-right :which-key "right window")

  ;; Project
  "p p" '(project-switch-project :which-key "switch project")
  "p f" '(project-find-file :which-key "project file")
  "p g" '(consult-grep :which-key "grep project")
  "p b" '(project-switch-to-buffer :which-key "project buffer")

  ;; Search
  "s s" '(consult-line :which-key "search line")
  "s g" '(consult-grep :which-key "grep")
  "s r" '(consult-ripgrep :which-key "ripgrep")

  ;; Git / Magit
  "g g" '(magit-status :which-key "magit status")
  "g d" '(magit-diff-unstaged :which-key "diff unstaged")
  "g l" '(magit-log :which-key "log")
  "g c" '(magit-commit :which-key "commit")
  "g p" '(magit-push :which-key "push")
  "g f" '(magit-fetch :which-key "fetch")
  "g b" '(magit-blame :which-key "blame")
  "g [" '(diff-hl-previous-hunk :which-key "previous hunk")
  "g ]" '(diff-hl-next-hunk :which-key "next hunk")

  ;; Toggle
  "t l" '(display-line-numbers-mode :which-key "toggle line numbers")
  "t w" '(whitespace-mode :which-key "toggle whitespace")
  "t t" '(my/vterm-new :which-key "new vterm")

  ;; Docs
  "d f" '(describe-function :which-key "describe function")
  "d v" '(describe-variable :which-key "describe variable")
  "d k" '(describe-key :which-key "describe key")
  "d m" '(describe-mode :which-key "describe mode")

  ;; Eglot / LSP
  "e a" '(eglot-code-actions :which-key "code actions")
  "e r" '(eglot-rename :which-key "rename")
  "e f" '(eglot-format :which-key "format")

  ;; Org / Notes
  "n c" '(org-capture :which-key "capture")
  "n a" '(org-agenda :which-key "agenda")

  ;; Buffer / Vterm digits (hidden from which-key)
  )

(provide 'keybinds)
;; keybinds.el ends here
