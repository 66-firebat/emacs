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

(defun sc--index-label (n)
  (if (< n 26) (string (+ ?a n))
    (concat (sc--index-label (1- (/ n 26))) (string (+ ?a (% n 26))))))

(defun sc--make-pairs (positions)
  (let ((i 0))
    (mapcar (lambda (p)
              (let* ((l (sc--index-label i))
                     (s (if (= 1 (length l)) (concat l " ") l)))
                (cl-incf i) (cons s p)))
            positions)))

(defun sc--num-str (pos)
  (let ((n (number-to-string (line-number-at-pos pos t))))
    (when (< (length n) 2) (setq n (concat " " n)))
    (concat (propertize n 'face 'sc-current-face)
            (propertize " ┣ " 'face 'sc-bump))))

(defun sc--lab-str (label)
  (concat (propertize label 'face 'sc-label-face)
          (propertize " ┃ " 'face 'sc-sep)))

(defun sc--sep-str ()
  "Just the separator — used as buffer-local fallback for continuation lines."
  (propertize " ┃ " 'face 'sc-sep))

(defun sc--make-ov (pos)
  (let ((end (min (+ pos 2) (point-max))))
    (when (<= end pos) (setq end pos))
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
  ;; Buffer-local line-prefix: just separator.  Shows on continuation lines
  ;; and as fallback for any line without an overlay.
  (setq-local line-prefix (sc--sep-str))
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
            (let ((lab (car pair)) (pos (cdr pair)))
              (let ((ov (sc--make-ov pos)))
                (if (= pos cur)
                    ;; Cursor line: show NUMBER ┣
                    (overlay-put ov 'line-prefix (sc--num-str pos))
                  ;; Non-cursor line: show LABEL ┃
                  (overlay-put ov 'line-prefix (sc--lab-str lab)))
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
;;  Scroll
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-scroll (win _start)
  (when (and sc-mode (eq (window-buffer win) (current-buffer)))
    (sc--rebuild)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Jump command
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc-avy-goto-line ()
  (interactive)
  (sc--rebuild)
  (let* ((candidates (copy-sequence sc--pairs)) (input ""))
    (when (null candidates) (user-error "No visible lines"))
    (while (cdr candidates)
      (condition-case nil
          (let ((char (read-key (format "Jump: %s" input))))
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
        (add-hook 'window-scroll-functions #'sc--on-scroll nil 'local))
    (remove-hook 'post-command-hook #'sc--on-post-command 'local)
    (remove-hook 'window-scroll-functions #'sc--on-scroll 'local)
    (mapc #'delete-overlay sc--ovs)
    (setq sc--ovs nil sc--pairs nil)
    (kill-local-variable 'line-prefix)
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
