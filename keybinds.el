;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  keybinds.el — All custom keybindings
;;
;;  Every keybinding in the Emacs configuration lives here.
;;  The `leader` key is defined in init.el (general-create-definer).
;; =============================================================================

;; ── Tab navigation (all modes) ──────────────────────────────
;; C-h / C-l to switch tabs via MRU-tabs.
;; Window navigation uses Evil's built-in C-w h/j/k/l.
(general-def '(normal insert visual)
  "C-h"  'my/MRU-tabs-backward
  "C-l"  'my/MRU-tabs-forward
  "C-u"  'evil-scroll-up)

;; ── Dired from anywhere (all modes) ───────────────────────
;; C-e opens dired in the eat terminal's current working directory.
;; Overrides evil-scroll-line-down in normal mode and move-end-of-line
;; in insert mode.
(general-def '(normal insert visual motion emacs)
  "C-e" 'my/dired-from-eat)

;; ── Quick buffer switch ──────────────────────────────────
;; Opens consult-buffer (includes vterm source).
;; Replaces evil-scroll-page-up in normal state.
(general-def '(normal insert visual)
  "C-b" 'consult-buffer)

;; ── Line motion (normal mode) ────────────────────────────────
;; Capital L/H for end/start of line (like $ and 0 in Vim).
;; Overrides Evil's default H/L (window-top/window-bottom).
(general-def '(normal visual visual-block visual-line)
  "L" 'evil-last-non-blank
  "H" 'evil-first-non-blank)

;; ── Select entire buffer (gg + V + G) ────────────────────────
(defun my/select-whole-buffer ()
  "Select the entire buffer in visual line mode.
Equivalent to `gg V G` in Vim (go to first line, enter visual
line mode, go to last line)."
  (interactive)
  (evil-goto-first-line)
  (evil-visual-line)
  (evil-goto-line (line-number-at-pos (point-max))))

(general-def '(normal visual visual-block visual-line)
  "C-a" 'my/select-whole-buffer)

;; ── Avy — jump to any visible character ────────────────────────
;; f + two chars → jump to that exact character pair
;; S + two chars → jump to that exact character pair (overridden below)
;; g s           → jump to a visible line number
;;
;; sc-avy-goto-char-2 is NOT an evil motion, so using it in operator-pending
;; mode (e.g., `d f`) would error.  my/avy-goto-char-2-motion wraps it as
;; a proper `evil-define-motion' with :type inclusive, so operators can
;; consume the range it produces.

;; Shows the bolt icon (󰠠) in the statuscolumn during f/F/;/gs jumps
;; by setting `sc--jump-active' so `sc--current-str' renders the bolt
;; instead of the slice icon.

(defun my/avy-goto-char-with-icon ()
  "Like `avy-goto-char' but shows bolt icon in statuscolumn."
  (interactive)
  (let ((sc--jump-active t))
    (when (fboundp 'evil-set-jump) (evil-set-jump))
    (sc--init)
    (unwind-protect
        (call-interactively 'avy-goto-char)
      (setq sc--jump-active nil)
      (sc--init))))

(defun my/avy-goto-char-timer-with-icon ()
  "Like `avy-goto-char-timer' but shows bolt icon in statuscolumn."
  (interactive)
  (let ((sc--jump-active t))
    (when (fboundp 'evil-set-jump) (evil-set-jump))
    (sc--init)
    (unwind-protect
        (call-interactively 'avy-goto-char-timer)
      (setq sc--jump-active nil)
      (sc--init))))

(evil-define-motion my/avy-goto-char-motion (count)
  "Jump to a visible character using avy.
Works in operator-pending mode (df, yf, cf, etc.)."
  :type inclusive
  :jump t
  (let ((c (read-char "char: " t)))
    (setq mark-active nil)
    (condition-case nil
        (avy-goto-char c count)
      (error nil))
    (setq mark-active nil)))

(evil-define-motion my/avy-goto-char-timer-motion (count)
  "Jump using avy char timer.
Works in operator-pending mode (dF, yF, cF, etc.)."
  :type inclusive
  :jump t
  (setq mark-active nil)
  (condition-case nil
      (avy-goto-char-timer count)
    (error nil))
  (setq mark-active nil))

(general-def '(normal visual visual-block visual-line)
  "f" 'my/avy-goto-char-with-icon
  "F" 'my/avy-goto-char-timer-with-icon
  ";" 'sc-avy-goto-line
  "gs" 'sc-avy-goto-line)

(general-def '(operator)
  "f" 'my/avy-goto-char-motion
  "F" 'my/avy-goto-char-timer-motion)

;; ── s / S — consult search ──────────────────────────────────────
;; s   → consult-line   (search current buffer)
;; S   → consult-ripgrep (search project with ripgrep)
;;
;; Overrides: s = evil-substitute, S = avy-goto-char-2.
;; Use x then i to substitute a char, or f for two-char Avy jumps.
;;
;; Both push the current cursor position into the Evil jump ring
;; before opening the consult UI, so C-o returns to where you were.
;; After selection, the search text is pushed into Emacs' search ring
;; so n/N (evil-search-next/previous) re-searches with that text.
(defun my/consult-line-with-jump ()
  "Push current position to jump ring, then call `consult-line'.
After selection, push the user's typed input into the search ring so
n/N works with the same search pattern."
  (interactive)
  (evil-set-jump)
  (let ((search-string nil))
    (condition-case nil
        (call-interactively 'consult-line)
      (quit nil))
    (when (and (bound-and-true-p consult--line-history)
               (car-safe consult--line-history))
      (setq search-string (car consult--line-history))
      (when (not (string= search-string ""))
        (isearch-update-ring search-string nil)
        (isearch-update-ring search-string t)
        (setq isearch-forward t
              evil-regexp-search t)))))

(defun my/consult-ripgrep-with-jump ()
  "Push current position to jump ring, then call `consult-ripgrep'.
After selection, push the user's typed input into the search ring so
n/N works with the same search pattern."
  (interactive)
  (evil-set-jump)
  (let ((search-string nil))
    (condition-case nil
        (call-interactively 'consult-ripgrep)
      (quit nil))
    (when (and (bound-and-true-p consult--grep-history)
               (car-safe consult--grep-history))
      (setq search-string (car consult--grep-history))
      (when (not (string= search-string ""))
        (isearch-update-ring search-string nil)
        (isearch-update-ring search-string t)
        (setq isearch-forward t
              evil-regexp-search t)))))

(general-def '(normal visual visual-block visual-line)
  "s" 'my/consult-line-with-jump
  "S" 'my/consult-ripgrep-with-jump)

;; ── n / N — search next/previous with auto-recenter ───────────
;; Wraps evil-search-next/previous and then calls
;; evil-scroll-line-to-center (zz) to keep the match centered.
;;
;; Overrides: n = evil-search-next, N = evil-search-previous.
;; Bound only in motion-state-map; visual and operator states
;; inherit via Evil's fallthrough mechanism.
(defun my/evil-search-next-and-center (&optional count)
  "Search forward for next match, then recenter the window."
  (interactive "P")
  (evil-search-next count)
  (recenter))

(defun my/evil-search-previous-and-center (&optional count)
  "Search backward for previous match, then recenter the window."
  (interactive "P")
  (evil-search-previous count)
  (recenter))

(define-key evil-motion-state-map "n" 'my/evil-search-next-and-center)
(define-key evil-motion-state-map "N" 'my/evil-search-previous-and-center)

;; ── C-i / TAB jump forward ─────────────────────────────────────
;; evil-want-C-i-jump t (init.el) handles TAB via evil-motion-state-map.
;; The kkp package (init.el) decodes C-i as [C-i] terminal-side; we
;; bind it here explicitly for normal and visual states.
(define-key evil-normal-state-map [C-i] 'evil-jump-forward)
(define-key evil-visual-state-map [C-i] 'evil-jump-forward)


;; ═════════════════════════════════════════════════════════════════
;;  SPC t t — Spawn Eat Terminal
;; ═════════════════════════════════════════════════════════════════

(defvar my-eat-index-cache -1
  "Index of the most recently spawned eat terminal.")

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

(defun my/eat-new ()
  "Spawn a new eat terminal at the lowest available index.
Buffer is named like \"0  19950\" (index +  + PID)."
  (interactive)
  (let ((index (my/eat-next-available))
        (shell (or explicit-shell-file-name
                   (getenv "ESHELL")
                   shell-file-name)))
    (setq my-eat-index-cache index)
    (let ((buf-name (format "%d  waiting" index)))
      (with-current-buffer (get-buffer-create buf-name)
        (eat-mode)
        (pop-to-buffer-same-window (current-buffer))
        ;; Start the terminal process (if not already running)
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

;; ═════════════════════════════════════════════════════════════════
;;  Eat Compose — Full Emacs buffer for typing into eat
;; ═════════════════════════════════════════════════════════════════
;; Opens a temporary buffer where you can write with full Emacs
;; editing, then sends the text to the eat terminal on C-c C-c.

(defvar-local my/eat-compose-source nil
  "Buffer of the eat terminal this compose buffer belongs to.")

(define-minor-mode my/eat-compose-mode
  "Minor mode for composing text to send to an eat terminal.
\nKeybindings:\n  C-c C-c  — Send text to eat and close\n  C-c C-k  — Cancel and close"
  :lighter " ✎"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-c") 'my/eat-compose-send)
            (define-key map (kbd "C-c C-k") 'my/eat-compose-cancel)
            map)
  (when my/eat-compose-mode
    (setq header-line-format
          " Compose text — C-c C-c to send, C-c C-k to cancel")))

(defun my/eat-compose ()
  "Open a compose buffer to write text for the current eat terminal.
If called from a visual selection, captures the selected text into
the compose buffer.  Otherwise starts empty.
\nType your text with full Emacs editing, then:\n  C-c C-c  — Send to eat and close\n  C-c C-k  — Cancel and close"
  (interactive)
  (unless (derived-mode-p 'eat-mode)
    (user-error "Not in an eat terminal buffer"))
  (let* ((source-buf (current-buffer))
         (selected (when (evil-visual-state-p)
                     (buffer-substring-no-properties
                      (region-beginning) (region-end)))))
    (switch-to-buffer (get-buffer-create "*eat-compose*"))
    (unless (zerop (buffer-size))
      (erase-buffer))
    (when selected
      (insert selected))
    (text-mode)
    (setq my/eat-compose-source source-buf)
    (my/eat-compose-mode 1)
    ;; Start in insert state: type immediately, ESC to use evil nav
    (evil-insert-state)))

(defun my/eat-compose-send ()
  "Send the compose buffer text to the eat terminal and close."
  (interactive)
  (let* ((new-text (buffer-string))
         ;; Clear existing shell input (C-u in readline) then insert new text
         (text (concat "\C-u" new-text "\n"))
         (source my/eat-compose-source)
         (compose-buf (current-buffer)))
    ;; Switch to eat buffer and send through its terminal input
    (when (buffer-live-p source)
      (switch-to-buffer source)
      (when (and (derived-mode-p 'eat-mode)
                 eat-terminal
                 (fboundp 'eat-term-send-string))
        (eat-term-send-string eat-terminal text)))
    ;; Clean up compose buffer
    (when (buffer-live-p compose-buf)
      (kill-buffer compose-buf))))

(defun my/eat-compose-cancel ()
  "Cancel composing and close the buffer."
  (interactive)
  (let ((source my/eat-compose-source))
    (if (and source (buffer-live-p source))
        (switch-to-buffer source)
      (switch-to-buffer (other-buffer)))
    (when (buffer-live-p (get-buffer "*eat-compose*"))
      (kill-buffer (get-buffer "*eat-compose*")))))

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

(defvar my/excluded-buffer-modes '()
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
;;  SPC e 0-9 — Jump to / spawn eat terminal by index
;; ═════════════════════════════════════════════════════════════════

(defun my/eat-buffer-list ()
  "Return all eat-mode buffers."
  (seq-filter (lambda (b)
                (with-current-buffer b (derived-mode-p 'eat-mode)))
              (buffer-list)))

(defun my/eat-index-strings ()
  "Return index strings like \"7\" for all existing eat buffers.
Sorted numerically."
  (let ((indices (delq nil
                       (mapcar (lambda (b)
                                 (when (string-match
                                        "\\`\\([0-9]+\\) "
                                        (buffer-name b))
                                   (match-string 1 (buffer-name b))))
                               (my/eat-buffer-list)))))
    (mapcar #'number-to-string
            (sort (mapcar #'string-to-number indices) #'<))))

(defun my/eat-spawn-at-index (index)
  "Create a new eat buffer with the given INDEX and return it."
  (let ((buf-name (format "%d  waiting" index))
        (shell (or explicit-shell-file-name
                   (getenv "ESHELL")
                   shell-file-name)))
    (with-current-buffer (get-buffer-create buf-name)
      (eat-mode)
      (unless (and eat-terminal
                   (eat-term-parameter eat-terminal 'eat--process))
        (eat-exec (current-buffer) (buffer-name)
                  "/usr/bin/env" nil
                  (list "sh" "-c" shell)))
      (when-let* ((proc (eat-term-parameter eat-terminal 'eat--process))
                  ((process-live-p proc)))
        (rename-buffer (format "%d  %d" index (process-id proc))))
      (current-buffer))))

;; ═════════════════════════════════════════════════════════════════
;;  Goto functions — called by digit keybindings below
;; ═════════════════════════════════════════════════════════════════

(defun my/eat-goto ()
  "Jump to or spawn an eat terminal by index.  Digit seeds the search."
  (interactive)
  (let* ((keys (this-single-command-keys))
         (key (aref keys (1- (length keys))))
         (initial (char-to-string key))
         (candidates (my/eat-index-strings))
         (input (completing-read "eat: " candidates nil nil initial)))
    (if (string= input "")
        (message "Cancelled")
      (let ((index (string-to-number input)))
        (if (member input candidates)
            (let ((buf (my/eat-buffer-by-index index)))
              (if buf (switch-to-buffer buf)
                (my/eat-spawn-at-index index)))
          (my/eat-spawn-at-index index)
          (message "Spawned eat %d" index))))))

(defun my/eat-buffer-by-index (index)
  "Return the eat buffer with the given INDEX, or nil."
  (car (seq-filter
        (lambda (b)
          (string-match-p (format "\\`%d " index) (buffer-name b)))
        (my/eat-buffer-list))))

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
;;  Dired — open from eat terminal's working directory
;; ═════════════════════════════════════════════════════════════════

(defvar my/dired-previous-buffer nil
  "Buffer that was current before `my/dired-from-eat' opened dired.
Used to return to the exact buffer when toggling dired closed.")

(defun my/dired-from-eat ()
  "Toggle a dired buffer open/closed.

When called from outside dired:
  (1) Visiting a file        → `dired-jump' (opens file's parent dir, point on file)
  (2) In an eat terminal     → opens dired at eat's `default-directory'
  (3) Any other buffer        → opens dired at the first eat buffer's
                                `default-directory', or falls back to the
                                current buffer's `default-directory'

When called from inside dired:
  Kills the dired buffer and returns to the previous buffer."
  (interactive)
  (if (derived-mode-p 'dired-mode)
      ;; ── In dired: kill it and go back to previous buffer ──
      (let ((prev my/dired-previous-buffer))
        (kill-buffer (current-buffer))
        (if (and prev (buffer-live-p prev))
            (switch-to-buffer prev)
          (message "No previous buffer to return to")))
    ;; ── Not in dired: record current buffer and open dired ──
    (setq my/dired-previous-buffer (current-buffer))
    (cond
     ;; (1) Visiting a file — dired-jump to its parent directory
     ((buffer-file-name)
      (dired-jump))
     ;; (2) In an eat terminal — use its default-directory (cwd)
     ((derived-mode-p 'eat-mode)
      (dired default-directory))
     ;; (3) Otherwise — try to find an eat buffer, else use current dir
     (t
      (let ((eat-buf (car (seq-filter
                           (lambda (b)
                             (with-current-buffer b
                               (derived-mode-p 'eat-mode)))
                           (buffer-list)))))
        (if eat-buf
            (dired (with-current-buffer eat-buf default-directory))
          (dired default-directory)))))))

;; ═════════════════════════════════════════════════════════════════
;;  SPC leader keybindings
;; ═════════════════════════════════════════════════════════════════

(leader
  "f f" '(find-file :which-key "find file")
  "f r" '(consult-recent-file :which-key "recent files")
  "f s" '(save-buffer :which-key "save buffer")
  "f o" '(other-frame :which-key "other frame")

  ;; Buffers
  "k k" '(my/switch-to-other-buffer :which-key "previous buffer")
  "b n" '(next-buffer :which-key "next buffer")
  "b p" '(previous-buffer :which-key "previous buffer")

  ;; Tabs — after switching, enter insert if landing on vterm
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

  ;; Pi — AI coding agent (prefix group: SPC p i)
  "p i" '(nil :which-key "pi")
  "p i i" '(pi-coding-agent :which-key "start/focus pi")
  "p i f" '(my/pi-frame :which-key "pi in new frame")
  "p i t" '(pi-coding-agent-toggle :which-key "toggle pi windows")
  "p i s" '(pi-coding-agent-open-session-file :which-key "open session file")
  "p i m" '(pi-coding-agent-select-model :which-key "select model")

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
  "t p" '(pi-coding-agent-toggle :which-key "toggle pi")

  ;; Eat compose
  "t e" '(my/eat-compose :which-key "eat compose")

  ;; Dired
  ;; (removed SPC d d — C-e now handles dired toggling globally)

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

;; ── Pi input buffer mode-map customizations ──────────────────────────────
(with-eval-after-load 'pi-coding-agent-input
  (general-def 'emacs pi-coding-agent-input-mode-map
    "M-RET" 'pi-coding-agent-send
    "S-RET" 'pi-coding-agent-send)

  (general-def '(normal insert emacs) pi-coding-agent-input-mode-map
    "C-c C-c" 'pi-coding-agent-send
    "C-c C-s" 'pi-coding-agent-queue-steering
    "C-c C-k" 'pi-coding-agent-abort
    "C-c C-p" 'pi-coding-agent-menu
    "C-c C-r" 'pi-coding-agent-resume-session))

;; ── Pi chat buffer mode-map customizations ──────────────────────────────
(with-eval-after-load 'pi-coding-agent-render
  (general-def 'normal pi-coding-agent-chat-mode-map
    "q" 'pi-coding-agent-quit))

;; ── Recent files ────────────────────────────────────────────────────────
(global-set-key (kbd "C-c C-o") 'consult-recent-file)

;; ── Find file ────────────────────────────────────────────────────────────
(global-set-key (kbd "C-c C-p") 'find-file)

;; ── Spawn Eat terminal ────────────────────────────────────────
;; Bound in the override keymap so it takes precedence over ALL
;; mode-specific bindings (sh-mode's sh-tmp-file, etc.)
(general-def :keymaps 'override
  "C-c C-t" 'my/eat-new)

;; ── Eat compose (from inside eat buffer) ─────────────────────
;; Note: C-c C-e is taken by eat's own `eat-emacs-mode' (makes buffer
;; read-only).  Use C-c C-m (m=compose/message) instead.
(define-key global-map (kbd "C-c C-m") 'my/eat-compose)

;; ── Kill current buffer ───────────────────────────────────────
(global-set-key (kbd "C-c C-u") 'kill-current-buffer)

;; ── Grease — Oil.nvim-style file manager ─────────────────────
(global-set-key (kbd "M-e") 'grease-toggle)


;; ═════════════════════════════════════════════════════════════════
;;  C-a Diagnostic Command
;; ═════════════════════════════════════════════════════════════════
;; Run M-x my/diagnose-c-a after C-a y to see what's on the clipboard.

(defun my/diagnose-c-a ()
  "Diagnose what\='s on the clipboard after C-a y.
Shows the clipboard content, KKP status, and key binding info."
  (interactive)
  (let* ((kr-len (length kill-ring))
         (kr-top (if (car kill-ring)
                    (substring-no-properties (car kill-ring) 0 (min 100 (length (car kill-ring))))
                  "(empty)"))
         (kr-top-full (car kill-ring))
         (wl-copy-alive (and (boundp 'wl-copy-process)
                             (process-live-p wl-copy-process)))
         ;; Actually read the system clipboard by shelling out directly
         (sys-clip (condition-case nil
                       (let ((result (shell-command-to-string "wl-paste -n 2>/dev/null | tr -d \\\\r | head -c 100")))
                         (if (string-empty-p result) "(empty)" result))
                     (error "(wl-paste failed)")))
         (kkp-active (bound-and-true-p kkp--active-terminal-list))
         (kkp-visited (bound-and-true-p kkp--setup-visited-terminal-list))
         (ca-normal (lookup-key evil-normal-state-map (kbd "C-a")))
         (ca-visual (lookup-key evil-visual-state-map (kbd "C-a")))
         (buf-size (buffer-size))
         (buf-preview (buffer-substring-no-properties
                       (point-min) (min (point-max) (+ (point-min) 100))))
         (has-8-6u-kill (and (car kill-ring)
                             (string-match-p "8;6u" (car kill-ring))))
         (has-8-6u-buf (save-excursion
                         (goto-char (point-min))
                         (search-forward "8;6u" nil t)))
         (has-8-6u-clip (string-match-p "8;6u" sys-clip)))
    (message "
╔══ C-a Diagnostic ═══════════════════════════════════════╗
║ KKP active:          %s       ║
║ KKP visited:         %s       ║
║ C-a in normal map:   %s       ║
║ interprogram-cut-fn: %s       ║
║ wl-copy process live:%s       ║
║ Kill-ring entries:   %d       ║
║ Kill-ring top:       %s       ║
║ 8;6u in kill-ring:   %s       ║
║ System clipboard:    %s       ║
║ 8;6u in clipboard:   %s       ║
║ Buffer contains 8;6u:%s       ║
║ Buffer size:         %d chars       ║
║ Buffer preview:      %s       ║
╚════════════════════════════════════════════════════════╝"
             kkp-active kkp-visited ca-normal
             interprogram-cut-function
             (if wl-copy-alive "YES" "no")
             kr-len kr-top
             (if has-8-6u-kill "YES!" "no")
             sys-clip
             (if has-8-6u-clip "YES!" "no")
             (if has-8-6u-buf "YES!" "no")
             buf-size buf-preview)))

(provide 'keybinds)
;; keybinds.el ends here
