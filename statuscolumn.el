;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  statuscolumn.el — Permanent letter jump labels in the statuscolumn
;;
;;  Buffer-local line-prefix = " ┃ " (just separator) — shows on continuation
;;  lines and as fallback.  Overlays on ALL first visual lines provide the
;;  actual content: NUMBER ┣ on cursor, LABEL ┃ on non-cursor lines.
;; =============================================================================

(defface sc-label-face '((t (:foreground "#444444" :background "#2b2b2b")))
  "Face for jump labels on non-current lines.")
(defface sc-current-face '((t (:foreground "#ff4400" :background "#2b2b2b")))
  "Face for absolute line number on current line.")
(defface sc-sep '((t (:foreground "#444444")))
  "Face for ┃ separator.")
(defface sc-bump '((t (:foreground "#ff4400" :weight bold)))
  "Face for ┣ separator on current line.")

;; ═════════════════════════════════════════════════════════════════════════════
;;  Helpers
;; ═════════════════════════════════════════════════════════════════════════════

(defconst sc--punct-labels
  (mapcar #'string '(?. ?\, ?@ ?! ?# ?$ ?% ?^ ?& ?* ?\( ?\) ?- ?+ ?= ?\[ ?\] ?{ ?} ?: ?\; ?< ?> ?? ?/ ?~))
  "Punctuation labels used after a-z for faster single-key jumping.")

(defun sc--index-label (n)
  "Return label for 0-based N: 0=a, 25=z, 26=., 27=,, 28=@, ..."
  (if (< n 26)
      (string (+ ?a n))
    (let ((p-idx (- n 26)))
      (if (< p-idx (length sc--punct-labels))
          ;; Single punctuation character (padded to 2 for alignment)
          (concat (nth p-idx sc--punct-labels) " ")
        ;; Fall back to double-letter after running out of punctuation
        (let* ((remaining (- p-idx (length sc--punct-labels)))
               (n (+ remaining 26)))
          (concat (sc--index-label (1- (/ n 26)))
                  (string (+ ?a (% n 26)))))))))

(defun sc--make-pairs (positions)
  (let ((i 0))
    (mapcar (lambda (p)
              (let* ((l (sc--index-label i))
                     (s (if (= 1 (length l)) (concat l " ") l)))
                (cl-incf i) (cons s p)))
            positions)))

(defun sc--slice-icon ()
  "Return a Nerd Font scrollbar-thumb icon based on point's position.
Maps 12.5%% bands to glyphs, same algorithm as doom-modeline."
  (let* ((total (max 1 (1- (point-max))))
         (pct (/ (float (1- (point))) total))
         (band (floor (* 8 pct))))
    (cond
     ((>= pct 1.0)  "󰪥")      ;; 100%%
     ((= band 0)    "󰄰")      ;;   0%% – 12.5%%
     ((= band 1)    "󰪞")      ;;  12.5%% – 25%%
     ((= band 2)    "󰪟")      ;;  25%% – 37.5%%
     ((= band 3)    "󰪠")      ;;  37.5%% – 50%%
     ((= band 4)    "󰪡")      ;;  50%% – 62.5%%
     ((= band 5)    "󰪢")      ;;  62.5%% – 75%%
     ((= band 6)    "󰪣")      ;;  75%% – 87.5%%
     ((= band 7)    "󰪤")      ;;  87.5%% – 100%% (exclusive)
     (t             "󰪤"))))

(defvar sc--mark-map nil
  "Hash table: buffer position -> mark character string.
Built by `sc--build-mark-map' for the current buffer.")

(defvar sc--recent-marks nil
  "Alist of (BOL . CHAR) — most recently set mark for each line.
Updated by `sc--track-recent-mark' via :after advice on evil-set-marker.")

(defun sc--track-recent-mark (char &optional pos &rest _)
  "Record that mark CHAR was set at POS (or point).
Removes the old position for the same mark character."
  (let ((bol (save-excursion
               (goto-char (or pos (point)))
               (line-beginning-position))))
    ;; Remove old entry with the same mark character from any line
    (setq sc--recent-marks
          (cl-remove-if (lambda (p) (= (cdr p) char)) sc--recent-marks))
    ;; Add new entry
    (push (cons bol char) sc--recent-marks)
    ;; Keep only the 50 most recent entries
    (when (> (length sc--recent-marks) 50)
      (setq sc--recent-marks (cl-subseq sc--recent-marks 0 50)))))

(when (fboundp 'evil-set-marker)
  (advice-add 'evil-set-marker :after #'sc--track-recent-mark))

(defun sc--forget-mark (char &rest _)
  "Remove mark CHAR from recent marks when deleted by delmarks."
  (setq sc--recent-marks
        (cl-remove-if (lambda (p) (= (cdr p) char)) sc--recent-marks)))

(when (fboundp 'evil-del-marker)
  (advice-add 'evil-del-marker :after #'sc--forget-mark))

(defun sc--build-mark-map ()
  "Build map of line-beginning positions to Evil mark characters.
Validates recent marks against evil-get-marker to handle deletions."
  (setq sc--mark-map (make-hash-table :test 'eql))
  (when (fboundp 'evil-get-marker)
    ;; First pass: iterate all marks via evil-get-marker (authoritative)
    (dolist (char (append (number-sequence ?a ?z) (number-sequence ?A ?Z)))
      (let ((pos (evil-get-marker char)))
        (when (and (numberp pos) (> pos 0) (<= pos (point-max)))
          (let ((bol (save-excursion
                       (goto-char pos) (line-beginning-position))))
            (puthash bol (string char) sc--mark-map)))))
    ;; Second pass: recent marks overwrite — but validate they still exist
    (dolist (pair sc--recent-marks)
      (let* ((char (cdr pair))
             (pos (evil-get-marker char)))
        (when (and (numberp pos) (> pos 0) (<= pos (point-max)))
          (let ((bol (save-excursion
                       (goto-char pos) (line-beginning-position))))
            (when (eq bol (car pair))
              (puthash bol (string char) sc--mark-map))))))))

(defun sc--mark-face (mark)
  "Propertized mark string with sc-label-face."
  (propertize mark 'face 'sc-label-face))

(defun sc--current-str (&optional mark)
  "Prefix: space + (mark or space) + space + icon + space + ┣ + space.  7 chars."
  (let ((icon (if sc--jump-active "󰠠" (sc--slice-icon))))
    (concat (propertize " " 'face 'sc-current-face)
            (if mark (propertize mark 'face 'sc-current-face)
              (propertize " " 'face 'sc-current-face))
            (propertize " " 'face 'sc-current-face)
            (propertize icon 'face 'sc-current-face)
            (propertize " " 'face 'sc-current-face)
            (propertize "┣ " 'face 'sc-bump))))

(defun sc--lab-str (label &optional mark)
  "Prefix: space + (mark or space) + space + label + ┃ + space.  7 chars."
  (let ((trimmed (string-trim-right label)))
    (concat (propertize " " 'face 'sc-label-face)
            (if mark (propertize mark 'face 'sc-label-face)
              (propertize " " 'face 'sc-label-face))
            (propertize " " 'face 'sc-label-face)
            (propertize trimmed 'face 'sc-label-face)
            (propertize (if (= 1 (length trimmed)) " " "") 'face 'sc-label-face)
            (propertize "┃ " 'face 'sc-sep))))

(defun sc--sep-str ()
  "Padded separator for continuation lines — ┃ with gray sc-sep face.  7 chars."
  (propertize "     ┃ " 'face 'sc-sep))

(defun sc--bump-str ()
  "Padded bump for current line's continuation — ┣ with orange sc-bump.  7 chars."
  (propertize "     ┣ " 'face 'sc-bump))

(defun sc--make-ov (pos)
  "Create overlay covering the entire logical line starting at POS."
  (let ((end (save-excursion
               (goto-char pos)
               (forward-line 1) (point))))
    (when (<= end pos) (setq end (min (1+ pos) (point-max))))
    (make-overlay pos end)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  State
;; ═════════════════════════════════════════════════════════════════════════════

(defvar-local sc--ovs nil)
(defvar-local sc--pairs nil)
(defvar-local sc--last-bol nil)
(defvar-local sc--last-tick nil)

;; ═════════════════════════════════════════════════════════════════════════════
;;  Rebuild — delete all overlays, create for every visible line
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--rebuild ()
  (mapc #'delete-overlay sc--ovs)
  (setq sc--ovs nil)
  (setq-local line-prefix (sc--sep-str))
  (setq-local wrap-prefix (sc--sep-str))
  (sc--build-mark-map)
  (let* ((win (get-buffer-window (current-buffer)))
         (cur (line-beginning-position))
         positions pairs new-ovs)
    (when win
      (let* ((ws (window-start win))
             (we (window-end win t)))
        (when (> we ws)
          (save-excursion
            (goto-char ws)
            (while (and (< (point) (point-max)) (< (point) we))
              (push (point) positions)
              (let ((prev (point)))
                (forward-line 1)
                (when (= (point) prev) (setq we (point))))))
          (setq positions (nreverse positions))
          (setq pairs (sc--make-pairs positions))
          (dolist (pair pairs)
            (let* ((lab (car pair)) (pos (cdr pair))
                   (mark (gethash pos sc--mark-map)))
              (let ((ov (sc--make-ov pos)))
                (if (= pos cur)
                    (progn
                      (overlay-put ov 'line-prefix (sc--current-str mark))
                      (overlay-put ov 'wrap-prefix (sc--bump-str)))
                  (overlay-put ov 'line-prefix (sc--lab-str lab mark)))
                (push ov new-ovs))))
          (setq sc--ovs new-ovs sc--pairs pairs
                sc--last-bol cur))))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Post-command — rebuild on cursor movement or buffer change
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-post-command ()
  (when (and sc-mode (not (minibufferp)))
    (let* ((bol (line-beginning-position))
           (tick (buffer-chars-modified-tick))
           (mod (and sc--last-tick (/= tick sc--last-tick))))
      (when (or mod (not (eq bol sc--last-bol)))
        (sc--rebuild)
        (setq sc--last-bol (line-beginning-position))
        (setq sc--last-tick tick)))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Refresh timer — periodic safety net for missed events
;; ═════════════════════════════════════════════════════════════════════════════

(defvar-local sc--refresh-timer nil
  "Repeating idle timer that periodically refreshes labels.")

(defvar-local sc--jump-active nil
  "Non-nil while ; jump is active — replaces slice icon with 󰠠.")

(defun sc--start-refresh-timer ()
  "Start a repeating idle timer to keep labels current."
  (unless sc--refresh-timer
    (let ((buf (current-buffer)))
      (setq sc--refresh-timer
            (run-with-idle-timer 0.1 0.1
              (lambda ()
                (when (buffer-live-p buf)
                  (with-current-buffer buf
                    (when sc-mode (sc--rebuild))))))))))

(defun sc--stop-refresh-timer ()
  "Stop the refresh timer."
  (when sc--refresh-timer
    (cancel-timer sc--refresh-timer)
    (setq sc--refresh-timer nil)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  After-change — timer already handles this, so just ensure tick is tracked
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-after-change (&rest _)
  "Mark buffer as changed so post-command can detect it."
  (when sc-mode
    (setq sc--last-tick nil)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Jump command
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc-avy-goto-line ()
  (interactive)
  (setq sc--jump-active t)
  (unwind-protect
      (progn
        (sc--rebuild)
        (let* ((candidates (copy-sequence sc--pairs)) (input ""))
          (when (null candidates) (user-error "No visible lines"))
          (while (cdr candidates)
            (condition-case nil
                (let ((char (read-key input)))
                  (cond ((= char ?\e) (user-error "Quit"))
                        ((= char ?\C-g) (keyboard-quit))
                        (t (setq input (concat input (string char)))
                           (setq candidates
                                 (cl-remove-if-not
                                  (lambda (c)
                                    (string-prefix-p input (string-trim (car c)) t))
                                  candidates))
                           (when (null candidates) (user-error "No match")))))
              (quit () (user-error "Quit"))))
          (when candidates
            (let ((target (cdar candidates))) (push-mark) (goto-char target)))))
    (setq sc--jump-active nil)
    (sc--rebuild)))

;;;###autoload
(defun sc-avy-goto-char-2 ()
  "Like `avy-goto-char-2' but shows bolt icon (󰠠) in statuscolumn.

Sets the bolt flag before `avy-goto-char-2' reads its first character,
then restores the slice icon on completion."
  (interactive)
  (setq sc--jump-active t)
  (sc--rebuild)
  (unwind-protect
      (call-interactively 'avy-goto-char-2)
    (setq sc--jump-active nil)
    (sc--rebuild)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  sc-mode
;; ═════════════════════════════════════════════════════════════════════════════

(define-minor-mode sc-mode
  "Statuscolumn with letter jump labels."
  :lighter "" :global nil
  (if sc-mode
      (progn
        (setq-local display-line-numbers nil)
        (setq-local left-margin-width 2)
        (when-let ((win (get-buffer-window (current-buffer))))
          (set-window-margins win 2 (cdr (window-margins win)))
          (sc--rebuild)
          (setq sc--last-tick (buffer-chars-modified-tick)))
        (add-hook 'post-command-hook #'sc--on-post-command nil 'local)
        (add-hook 'after-change-functions #'sc--on-after-change nil 'local)
        (sc--start-refresh-timer))
    (remove-hook 'post-command-hook #'sc--on-post-command 'local)
    (remove-hook 'after-change-functions #'sc--on-after-change 'local)
    (sc--stop-refresh-timer)
    (mapc #'delete-overlay sc--ovs)
    (setq sc--ovs nil sc--pairs nil)
    (kill-local-variable 'line-prefix)
    (kill-local-variable 'wrap-prefix)
    (kill-local-variable 'display-line-numbers)
    (kill-local-variable 'left-margin-width)
    (when-let ((win (get-buffer-window (current-buffer))))
      (set-window-margins win 0 (cdr (window-margins win))))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Global mode
;; ═════════════════════════════════════════════════════════════════════════════

(define-minor-mode global-sc-mode
  "Global statuscolumn with letter labels."
  :global t :lighter ""
  (if global-sc-mode
      (progn
        (setq-default left-margin-width 2)
        (global-sc-mode--enable-all)
        (add-hook 'after-change-major-mode-hook #'global-sc-mode--enable-buffer))
    (global-sc-mode--disable-all)
    (remove-hook 'after-change-major-mode-hook #'global-sc-mode--enable-buffer)))

(defun global-sc-mode--enable-buffer ()
  (when (and global-sc-mode (not sc-mode)) (sc-mode 1)))

(defun global-sc-mode--enable-all ()
  (dolist (buf (buffer-list))
    (with-current-buffer buf (global-sc-mode--enable-buffer))))

(defun global-sc-mode--disable-all ()
  (dolist (buf (buffer-list))
    (with-current-buffer buf (when sc-mode (sc-mode -1)))))

(provide 'statuscolumn)
;; statuscolumn.el ends here
