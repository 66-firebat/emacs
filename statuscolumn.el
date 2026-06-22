;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  statuscolumn.el — Visual Line Number Column
;;
;;  Displays an absolute line number and separator before every
;;  visual (displayed) line, including continuation/wrapped lines.
;;
;;  - Absolute line numbers only
;;  - Visual lines (each wrapped line gets its own number)
;;  - Dynamic width — pads to fit the largest line number in the buffer
;;  - Current line uses "┣" separator; all other lines use "┃"
;;  - All visual lines of the current logical line get "┣"
;;  - Works in all buffers and all modes
;;  - Not toggleable — always on
;; =============================================================================

;; ── Faces ─────────────────────────────────────────────────────────────────
;; Faces are defined here as fallback defaults. The firebat theme (theme.el)
;; overrides these colors when active via custom-theme-set-faces.

(defface sc-line-number
  '((t (:foreground "#444444")))
  "Face for the line number portion of the status column.")

(defface sc-separator
  '((t (:foreground "#444444")))
  "Face for the ┃ separator in the status column.")

(defface sc-bump
  '((t (:foreground "#ff4400" :weight bold)))
  "Face for the ┣ separator on the current line.")

;; ── Config ─────────────────────────────────────────────────────────────────

(defvar sc-excluded-modes
  '(pi-coding-agent-chat-mode
    pi-coding-agent-input-mode
    eat-mode)
  "Major modes (or derived modes) to exclude from status-column rendering.
Add any mode where line-number overlays would conflict with the buffer's
own display (e.g., terminal emulators like eat, chat UIs, special modes).")

;; ── State ──────────────────────────────────────────────────────────────────

(defvar-local sc--overlays nil
  "List of active status-column overlays in the current buffer.")

(defvar-local sc--change-fn nil
  "Cached after-change function so we can remove it later.")

;; ── Helpers ────────────────────────────────────────────────────────────────

(defun sc--num-width ()
  "Return the number of characters needed for the largest line number."
  (let ((max-line (line-number-at-pos (point-max) 'absolute)))
    (max 5 (length (format "%d" max-line)))))

(defun sc--build-prefix (logical-line is-cur)
  "Build a propertized string like \" 3 ┃ \" for LOGICAL-LINE.
IS-CUR non-nil means this is a visual line of the current line,
so use ┣ instead of ┃."
  (let* ((width  (sc--num-width))
         (fmt    (format "%%%dd" width))
         (sep-char (if is-cur " ┣ " " ┃ "))
         (sep-face (if is-cur 'sc-bump 'sc-separator))
         (num    (propertize (format fmt logical-line) 'face 'sc-line-number))
         (sep    (propertize sep-char 'face sep-face)))
    (concat num sep)))

;; ── Refresh ────────────────────────────────────────────────────────────────

(defun sc--refresh (&optional _window _display-lines)
  "Update status-column overlays for every VISUAL line in the window.

Each overlay shows \"NN ┃ \" before the text, where NN is the logical
line number padded to fit the widest line number in the buffer.

Uses `vertical-motion' so continuation (wrapped) lines are covered too."
  ;; Remove all old overlays
  (mapc #'delete-overlay sc--overlays)
  (setq sc--overlays nil)

  (let* ((cur-pos   (point))
         (cur-logical (line-number-at-pos cur-pos 'absolute))
         (w-start   (window-start))
         (w-end     (max (or (window-end nil t) (point)) (point))))
    (when (and w-start w-end (> w-end w-start))
      (catch 'done
        (save-excursion
          (goto-char w-start)
          (while (<= (point) w-end)
            ;; At EOB with no trailing newline? Skip.
            (when (and (eobp) (or (bobp) (/= (char-before (point-max)) ?\n)))
              (throw 'done nil))

            ;; Does this visual line belong to the current logical line?
            (let* ((logical   (line-number-at-pos (point) 'absolute))
                   (is-cur    (= logical cur-logical))
                   (prefix    (sc--build-prefix logical is-cur))
                   (ov        (make-overlay (point) (point))))
              (overlay-put ov 'before-string prefix)
              (overlay-put ov 'sc-p t)
              (push ov sc--overlays))

            ;; Move to the next VISUAL line
            (when (eobp) (throw 'done nil))
            (let ((last-pos (point)))
              (vertical-motion 1)
              (when (= (point) last-pos) (throw 'done nil))))
          )))))


;; ── Activation / Deactivation ─────────────────────────────────────────────

(defun sc--activate ()
  "Enable status-column line numbers in the current buffer.
Skips buffers whose major mode (or a derived mode) is listed in
`sc-excluded-modes'."
  (when (apply #'derived-mode-p sc-excluded-modes)
    (cl-return-from sc--activate))
  (sc--refresh)
  (add-hook 'post-command-hook       #'sc--refresh nil 'local)
  (add-hook 'window-scroll-functions #'sc--refresh nil 'local)
  (setq sc--change-fn (lambda (&rest _) (sc--refresh)))
  (add-hook 'after-change-functions  sc--change-fn nil 'local))

(defun sc--deactivate ()
  "Remove status-column overlays and hooks from the current buffer."
  (mapc #'delete-overlay sc--overlays)
  (setq sc--overlays nil)
  (remove-hook 'post-command-hook       #'sc--refresh 'local)
  (remove-hook 'window-scroll-functions #'sc--refresh 'local)
  (when sc--change-fn
    (remove-hook 'after-change-functions sc--change-fn 'local)
    (setq sc--change-fn nil)))

;; ── Global activation ──────────────────────────────────────────────────────

;; Activate in the current buffer immediately
(sc--activate)

;; Activate in any new buffer that appears in a window
(add-hook 'window-buffer-change-functions
          (lambda (_window) (sc--activate)))

(provide 'statuscolumn)
;; statuscolumn.el ends here
