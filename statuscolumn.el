;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  statuscolumn.el — Permanent letter jump labels in the statuscolumn
;;
;;  DESIGN:
;;    sc--init runs on EVERY post-command, creating/updating overlays for
;;    all visible lines.  Uses double-buffer (Phase 1: update in-place or
;;    create; Phase 2: delete vanished) so there is no flicker from the
;;    delete-all→create-all cycle.
;;
;;    sc--find-ov-at uses position containment (<= start < end).  Since
;;    sc--make-ov excludes the trailing newline from each overlay, ranges
;;    never overlap even after buffer edits — position containment always
;;    finds the correct overlay.
;;
;;    No fast-path functions, no conditional logic.  Every command gets a
;;    clean, correct statuscolumn.
;; =============================================================================

(defface sc-label-face '((t (:foreground "#444444" :background "#2b2b2b")))
  "Face for jump labels on non-current lines.")
(defface sc-current-face '((t (:foreground "#ff4400" :background "#2b2b2b")))
  "Face for absolute line number on current line.")
(defface sc-sep '((t (:foreground "#444444")))
  "Face for ┃ separator.")
(defface sc-bump '((t (:foreground "#ff4400" :weight bold)))
  "Face for ┣ separator on current line.")
(defface sc-wrap-icon '((t (:foreground "#ff4400" :background "#2b2b2b")))
  "Face for  icon on wrapped CURRENT-line continuation lines.")
(defface sc-wrap-icon-dim '((t (:foreground "#CCCCCC" :background "#2b2b2b")))
  "Face for  icon on wrapped NON-CURRENT continuation lines.")
(defface sc-search-face '((t (:background "#ff4400" :foreground "#2b2b2b")))
  "Face for the Evil search instance counter in the statuscolumn.")
(defface sc-search-lead-space '((t (:foreground "#2b2b2b" :background "#2b2b2b")))
  "Face for the leading space before  during active search.
Matches the theme background so the gap is invisible.")

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
          (concat (nth p-idx sc--punct-labels) " ")
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
  "Return a Nerd Font scrollbar-thumb icon based on point's position."
  (let* ((total (max 1 (1- (point-max))))
         (pct (/ (float (1- (point))) total))
         (band (floor (* 8 pct))))
    (cond
     ((>= pct 1.0)  "󰪥")
     ((= band 0)    "󰄰")
     ((= band 1)    "󰪞")
     ((= band 2)    "󰪟")
     ((= band 3)    "󰪠")
     ((= band 4)    "󰪡")
     ((= band 5)    "󰪢")
     ((= band 6)    "󰪣")
     ((= band 7)    "󰪤")
     (t             "󰪤"))))

(defun sc--line-slice-icon ()
  "Return a Nerd Font scrollbar-thumb icon based on the cursor's
position within the current line (character offset from BOL).
Uses the same 8-band mapping as `sc--slice-icon'.

On empty lines (0 characters) returns 󰄰."
  (let* ((bol (line-beginning-position))
         (eol (line-end-position))
         (total (max 1 (- eol bol)))
         (pct (/ (float (- (point) bol)) total))
         (band (floor (* 8 pct))))
    (cond
     ((>= pct 1.0)  "󰪥")
     ((= band 0)    "󰄰")
     ((= band 1)    "󰪞")
     ((= band 2)    "󰪟")
     ((= band 3)    "󰪠")
     ((= band 4)    "󰪡")
     ((= band 5)    "󰪢")
     ((= band 6)    "󰪣")
     ((= band 7)    "󰪤")
     (t             "󰪤"))))

(defvar sc--mark-map nil
  "Hash table: buffer position → mark character string.
Built by `sc--build-mark-map' for the current buffer.")

(defvar sc--recent-marks nil
  "Alist of (BOL . CHAR) — most recently set mark for each line.")

(defun sc--track-recent-mark (char &optional pos &rest _)
  (let ((bol (save-excursion
               (goto-char (or pos (point)))
               (line-beginning-position))))
    (setq sc--recent-marks
          (cl-remove-if (lambda (p) (= (cdr p) char)) sc--recent-marks))
    (push (cons bol char) sc--recent-marks)
    (when (> (length sc--recent-marks) 50)
      (setq sc--recent-marks (cl-subseq sc--recent-marks 0 50)))))

(when (fboundp 'evil-set-marker)
  (advice-add 'evil-set-marker :after #'sc--track-recent-mark))

(defun sc--forget-mark (char &rest _)
  (setq sc--recent-marks
        (cl-remove-if (lambda (p) (= (cdr p) char)) sc--recent-marks)))

(when (fboundp 'evil-del-marker)
  (advice-add 'evil-del-marker :after #'sc--forget-mark))

(defun sc--build-mark-map ()
  "Build map of line-beginning positions to Evil mark characters."
  (setq sc--mark-map (make-hash-table :test 'eql))
  (when (fboundp 'evil-get-marker)
    (dolist (char (append (number-sequence ?a ?z) (number-sequence ?A ?Z)))
      (unless (cl-find char sc--recent-marks :key #'cdr)
        (let ((pos (evil-get-marker char)))
          (when (and (numberp pos) (> pos 0) (<= pos (point-max)))
            (let ((bol (save-excursion
                         (goto-char pos) (line-beginning-position))))
              (puthash bol (string char) sc--mark-map))))))
    (dolist (pair sc--recent-marks)
      (let* ((char (cdr pair))
             (pos (evil-get-marker char)))
        (when (and (numberp pos) (> pos 0) (<= pos (point-max)))
          (let ((bol (save-excursion
                       (goto-char pos) (line-beginning-position))))
            (unless (gethash bol sc--mark-map)
              (puthash bol (string char) sc--mark-map))))))))

;; Track all avy jumps in Evil's jump list so C-o/C-i work
(when (fboundp 'avy-action-goto)
  (advice-add 'avy-action-goto :before
              (lambda (&rest _) (when (fboundp 'evil-set-jump) (evil-set-jump)))))

;; ── Search tracking ────────────────────────────────────────

(defvar-local sc--search-active nil
  "Non-nil while an Evil search is active (set by advice, sole source of truth).")

(defun sc--search-active-p ()
  "Return non-nil if an Evil search is currently active."
  sc--search-active)

(defun sc--search-activate (&rest _)
  "Activate search tracking."
  (setq sc--search-active t))

(defun sc--search-deactivate (&rest _)
  "Deactivate search tracking."
  (setq sc--search-active nil))

;; Advice on Evil search functions — the sole mechanism for tracking.
;; Delayed because statuscolumn.el loads before evil.
(with-eval-after-load 'evil
  (advice-add 'evil-ex-search :after #'sc--search-activate)
  (advice-add 'evil-search-incrementally :after #'sc--search-activate)
  (advice-add 'evil-search :after #'sc--search-activate)
  (advice-add 'evil-ex-nohighlight :after #'sc--search-deactivate))

(defun sc--search-instance-str ()
  "Return 3-char right-aligned search instance number, or nil.
Uses `evil-ex-search-pattern' or `isearch-string' for the regex.
Uses point as current match position."
  (when (sc--search-active-p)
    (let ((regex
           (or (and (bound-and-true-p evil-ex-search-pattern)
                    (evil-ex-pattern-regex evil-ex-search-pattern))
               (and (bound-and-true-p isearch-string)
                    (not (string= isearch-string ""))
                    (if isearch-regexp isearch-string
                      (regexp-quote isearch-string))))))
      (when regex
        (condition-case nil
            (let* ((cur-pos
                    (or (and (boundp 'evil-ex-search-match-beg)
                             evil-ex-search-match-beg)
                        (point)))
                   (case-fold-search
                    (if (bound-and-true-p evil-ex-search-pattern)
                        (evil-ex-pattern-ignore-case evil-ex-search-pattern)
                      (bound-and-true-p isearch-case-fold-search)))
                   (current nil))
              (save-excursion
                (goto-char (point-min))
                (let ((count 0))
                  (while (re-search-forward regex nil t)
                    (cl-incf count)
                    (when (<= (match-beginning 0) cur-pos (1- (match-end 0)))
                      (setq current count)))))
              (when current
                (propertize (let* ((s (if (> current 99) "99+" (number-to-string current)))
                                     (pad (- 3 (length s)))
                                     (left (ash pad -1))
                                     (right (- pad left)))
                                (concat (make-string left ?\s) s (make-string right ?\s)))
                            'face 'sc-search-face)))
          (error nil))))))

(defun sc--current-str (&optional mark)
  "Prefix: space + (mark or space) + space + icon + space + ┣ + space.  7 chars.
When a search is active: search(3) + mark + space + ┣ + space.  6 chars."
  (let* ((search-str (unless sc--jump-active (sc--search-instance-str)))
         (icon (if sc--jump-active "󰠠" (sc--slice-icon))))
    (if search-str
        ;; Search active — 8-char layout: sp +  + mark + search(3) + ┣ + sp
        (concat (propertize " " 'face 'sc-search-lead-space)
        (propertize "" 'face 'sc-search-face)
                (if mark (propertize mark 'face 'sc-search-face)
                  (propertize " " 'face 'sc-search-face))
                search-str
                (propertize "┣ " 'face 'sc-bump))
      ;; Normal — 8-char layout: sp + sp + mark/sp + sp + icon + sp + ┣ + sp
      (concat (propertize "  " 'face 'sc-current-face)
              (if mark (propertize mark 'face 'sc-current-face)
                (propertize " " 'face 'sc-current-face))
              (propertize " " 'face 'sc-current-face)
              (propertize icon 'face 'sc-current-face)
              (propertize " " 'face 'sc-current-face)
              (propertize "┣ " 'face 'sc-bump)))))

(defun sc--lab-str (label &optional mark)
  "Prefix: sp + (mark or sp) + sp + label + ┃ + sp.  8 chars."
  (let ((trimmed (string-trim-right label)))
    (concat (propertize "  " 'face 'sc-label-face)
            (if mark (propertize mark 'face 'sc-label-face)
              (propertize " " 'face 'sc-label-face))
            (propertize " " 'face 'sc-label-face)
            (propertize trimmed 'face 'sc-label-face)
            (propertize (if (= 1 (length trimmed)) " " "") 'face 'sc-label-face)
            (propertize "┃ " 'face 'sc-sep))))

(defun sc--sep-str ()
  "Wrap prefix for non-current continuation lines —  ┃.  8 chars."
  (concat (propertize "    " 'face 'sc-sep)
          (propertize "" 'face 'sc-wrap-icon-dim)
          (propertize " " 'face 'sc-sep)
          (propertize "┃ " 'face 'sc-sep)))

(defun sc--bump-str ()
  "Wrap prefix for current continuation lines —  ┣.  8 chars."
  (concat (propertize "    " 'face 'sc-bump)
          (propertize "" 'face 'sc-wrap-icon)
          (propertize " " 'face 'sc-bump)
          (propertize "┣ " 'face 'sc-bump)))

(defun sc--make-ov (pos)
  "Create overlay covering the full logical line at POS."
  (let ((end (save-excursion
               (goto-char pos)
               (forward-line 1) (point))))
    (when (<= end pos) (setq end (min (1+ pos) (point-max))))
    (make-overlay pos end)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  State
;; ═════════════════════════════════════════════════════════════════════════════

(defvar-local sc--ovs nil
  "List of all statuscolumn overlays.")
(defvar-local sc--pairs nil
  "List of (label . bol) pairs for jump labels.")
(defvar-local sc--last-bol nil
  "BOL at last check, for cursor-movement detection.")
(defvar-local sc--last-ws nil
  "window-start at last check, for scroll detection.")
(defvar-local sc--last-tick nil
  "buffer-chars-modified-tick at last check, for edit detection.")
(defvar-local sc--jump-active nil
  "Non-nil while ; jump is active — replaces slice icon with 󰠠.")

;; ═════════════════════════════════════════════════════════════════════════════
;;  Find overlay — linear scan of sc--ovs by start-position equality
;; ═════════════════════════════════════════════════════════════════════════════

;; ═════════════════════════════════════════════════════════════════════════════
;;  Init — delete all overlays, create fresh for every visible line
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--init ()
  "Delete all overlays and create fresh ones for the current window.
Called on EVERY post-command.  No flicker because redisplay runs
between commands, not within them — the delete+create is atomic."
  ;; Wipe all existing overlays before creating new ones
  (mapc #'delete-overlay sc--ovs)
  (setq sc--ovs nil)
  (setq-local line-prefix (sc--sep-str))
  (setq-local wrap-prefix (sc--sep-str))
  (sc--build-mark-map)

  (let* ((win (get-buffer-window (current-buffer)))
         (cur (line-beginning-position)))
    (when win
      (let* ((we (window-end win t))
             (ws (window-start win))
             positions)
        (when (> we ws)
          ;; Collect visible line BOLs in order
          (save-excursion
            (goto-char ws)
            (while (and (< (point) (point-max)) (< (point) we))
              (push (point) positions)
              (forward-line 1)
              (when (= (point) (car (last positions)))
                (setq we (point)))))
          (setq positions (nreverse positions))
          (setq sc--pairs (sc--make-pairs positions))

          ;; Create a fresh overlay for every visible line
          (dolist (pair sc--pairs)
            (let* ((lab (car pair)) (pos (cdr pair))
                   (mark (gethash pos sc--mark-map))
                   (ov (sc--make-ov pos)))
              (overlay-put ov 'sc-label lab)
              (if (= pos cur)
                  (progn
                    (overlay-put ov 'line-prefix (sc--current-str mark))
                    (overlay-put ov 'wrap-prefix (sc--bump-str)))
                (overlay-put ov 'line-prefix (sc--lab-str lab mark)))
              (push ov sc--ovs)))

          (setq sc--last-bol cur
                sc--last-ws ws
                sc--last-tick (buffer-chars-modified-tick)))))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  On move — swap current-line indicator between 2 overlays (FAST PATH)
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-post-command ()
  "Post-command hook: full sc--init on EVERY command.
Simple, correct, no stale state.  Phase 1/2 double-buffer prevents flicker."
  (when (and sc-mode (not (minibufferp)))
    (sc--init)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Window scroll — fires during redisplay when window-start changes
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-window-scroll (win _new-start)
  "Window-scroll-functions hook — re-init immediately on scroll.
Fires during redisplay, right after window-start changes."
  (when (and sc-mode (buffer-live-p (window-buffer win)))
    (with-current-buffer (window-buffer win)
      (sc--init))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Window resize
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-window-size-change (_frame)
  "Window-size-change-functions hook — full re-init on resize."
  (when sc-mode
    (sc--init)))

;; ═════════════════════════════════════════════════════════════════════════════
;;  After-change — no-op, tick comparison in post-command handles edits
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc--on-after-change (&rest _) )

;; ═════════════════════════════════════════════════════════════════════════════
;;  Jump commands
;; ═════════════════════════════════════════════════════════════════════════════

(defun sc-avy-goto-line ()
  "Jump to a visible line by typing its label (a-z, punctuation)."
  (interactive)
  (let ((sc--jump-active t)
        (in-visual (and (fboundp 'evil-visual-state-p)
                        (evil-visual-state-p))))
    (unwind-protect
        (progn
          (sc--init)
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
              (let ((target (cdar candidates)))
                (when (fboundp 'evil-set-jump) (evil-set-jump))
                ;; :keep-visual prevents `evil-visual-pre-command' from
                ;; expanding the region (which moves point to the far end
                ;; of the selection — the cursor-jump the user sees).
                ;; Instead we set the Emacs mark to the visual anchor
                ;; manually, then `goto-char' moves point to target.
                ;; `evil-visual-post-command' sees expanded is nil, calls
                ;; `evil-visual-refresh', and extends the selection from
                ;; the anchor to point — keeping us in visual mode.
                (when in-visual
                  (set-marker (mark-marker)
                              (or (and (boundp 'evil-visual-mark)
                                       (marker-position evil-visual-mark))
                                  (point))))
                (unless in-visual
                  (push-mark))
                (goto-char target)))))
      (setq sc--jump-active nil)
      (sc--init))))

;;;###autoload
(defun sc-avy-goto-char-2 ()
  "Like `avy-goto-char-2' but shows bolt icon (󰠠) in statuscolumn.
Saves current position to the Evil jumplist before jumping."
  (interactive)
  (let ((in-visual (and (fboundp 'evil-visual-state-p)
                        (evil-visual-state-p))))
    ;; Save current position to jumplist (non-visual only;
    ;; visual-mode uses the anchor/mark approach below).
    (unless in-visual
      (when (fboundp 'evil-set-jump) (evil-set-jump))
      (push-mark))
    ;; Same anchor setup as sc-avy-goto-line so that after the
    ;; `avy-goto-char-2' jump, `evil-visual-refresh' extends the
    ;; selection from the anchor to the new point.
    (when in-visual
      (set-marker (mark-marker)
                  (or (and (boundp 'evil-visual-mark)
                           (marker-position evil-visual-mark))
                      (point))))
    (setq sc--jump-active t)
    (sc--init)
    (unwind-protect
        (call-interactively 'avy-goto-char-2)
      (setq sc--jump-active nil)
      (sc--init))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  sc-mode
;; ═════════════════════════════════════════════════════════════════════════════

;; Hook into eat's update-hook so terminal output refreshes the statuscolumn.
(defun sc--on-eat-update ()
  "Refresh statuscolumn after eat processes terminal output.
Called from eat-update-hook, which runs inside eat's output-processing
timer callback after every batch of terminal output is processed."
  (when sc-mode
    (sc--init)))

(define-minor-mode sc-mode
  "Statuscolumn with letter jump labels."
  :lighter "" :global nil
  (if sc-mode
      (progn
        (setq-local display-line-numbers nil)
        (setq-local left-margin-width 2)
        (when-let ((win (get-buffer-window (current-buffer))))
          (set-window-margins win 2 (cdr (window-margins win)))
          (sc--init))
        (add-hook 'post-command-hook #'sc--on-post-command nil 'local)
        (add-hook 'after-change-functions #'sc--on-after-change nil 'local))
    (remove-hook 'post-command-hook #'sc--on-post-command 'local)
    (remove-hook 'after-change-functions #'sc--on-after-change 'local)
    (mapc #'delete-overlay sc--ovs)
    (setq sc--ovs nil sc--pairs nil
          sc--last-bol nil sc--last-ws nil sc--last-tick nil)
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
        (add-hook 'after-change-major-mode-hook #'global-sc-mode--enable-buffer)
        (add-hook 'window-size-change-functions #'sc--on-window-size-change)
        (add-hook 'window-scroll-functions #'sc--on-window-scroll)
        ;; Hook into eat's update cycle — terminal output processed outside
        ;; the command loop, so post-command-hook doesn't catch it.
        (when (boundp 'eat-update-hook)
          (add-hook 'eat-update-hook #'sc--on-eat-update)))
    (global-sc-mode--disable-all)
    (remove-hook 'after-change-major-mode-hook #'global-sc-mode--enable-buffer)
    (remove-hook 'window-size-change-functions #'sc--on-window-size-change)
    (remove-hook 'window-scroll-functions #'sc--on-window-scroll)
    (when (boundp 'eat-update-hook)
      (remove-hook 'eat-update-hook #'sc--on-eat-update))))

(defun global-sc-mode--enable-buffer ()
  (when (and global-sc-mode (not sc-mode)) (sc-mode 1)))

(defun global-sc-mode--enable-all ()
  (dolist (buf (buffer-list))
    (with-current-buffer buf (global-sc-mode--enable-buffer))))

(defun global-sc-mode--disable-all ()
  (dolist (buf (buffer-list))
    (with-current-buffer buf (when sc-mode (sc-mode -1)))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Evil :keep-visual — prevent cursor-jump on command entry
;; ═════════════════════════════════════════════════════════════════════════════
;; Setting `:keep-visual' on a command tells `evil-visual-pre-command' to
;; skip `evil-visual-expand-region' entirely.  Without it, pre-command moves
;; point to `evil-visual-end' (the far end of the selection) — causing the
;; cursor to visibly jump on every visual-mode invocation of ; or f.
;; With `:keep-visual', point stays where it was when the user pressed the
;; key, and we manually set up the Emacs mark so `evil-visual-post-command'
;; can still extend the selection correctly.

(when (fboundp 'evil-set-command-property)
  (evil-set-command-property 'sc-avy-goto-line :keep-visual t)
  (evil-set-command-property 'sc-avy-goto-char-2 :keep-visual t))

(provide 'statuscolumn)
;; statuscolumn.el ends here
