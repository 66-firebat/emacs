;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  MRU-tabs.el — Scratch-built per-window tab line (v4)
;;
;;  NO MRU-tabs package internals.  Everything built from raw Emacs Lisp.
;;
;;  Architecture:
;;    Each window has a `my/MRU-tabs-data' parameter containing all tab
;;    state.  The header-line-format has two :eval elements:
;;      [0] group-icon + line number
;;      [1] tab bar (fully self-rendered)
;;
;;  FILES: LOGIC.md, PLAN.md, ISSUES.md
;; =============================================================================

;; ── Our own minor mode (no external package needed) ──────
(require 'cl-lib)

(defvar MRU-tabs-mode-map (make-sparse-keymap)
  "Keymap for MRU-tabs-mode.")

(defcustom MRU-tabs-display-line-format 'header-line-format
  "Variable used to display the MRU-tabs tab line."
  :type 'symbol
  :group 'MRU-tabs)

(define-minor-mode MRU-tabs-mode
  "Minor mode for MRU-tabs tab bar display.

When enabled, the header line shows a group-organized, MRU-ordered
tab bar with icons.  All rendering is self-built in raw Emacs Lisp."
  :global t
  :keymap MRU-tabs-mode-map)

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 1 — Custom faces                                  ║
;; ╚══════════════════════════════════════════════════════════════╝

(defface my/ct-tab-selected
  '((t (:background "#8C8C8C" :foreground "#2b2b2b")))
  "Face for the selected tab."
  :group 'MRU-tabs)

(defface my/ct-tab-unselected
  '((t (:background "#5C5C5C" :foreground "#2b2b2b")))
  "Face for unselected tabs."
  :group 'MRU-tabs)

(defface my/ct-group-icon
  '((t (:background "#ff4400" :foreground "#2b2b2b" :weight bold)))
  "Face for the group icon segment."
  :group 'MRU-tabs)

(defface my/ct-overflow
  '((t (:foreground "#ff4400" :background "#2b2b2b" :weight bold)))
  "Face for the overflow indicator."
  :group 'MRU-tabs)

(defvar my/ct--overflow-icons
  [" "       ;; 0 — unused (no overflow)
   "󰲠"      ;; 1
   "󰲢"      ;; 2
   "󰲤"      ;; 3
   "󰲦"      ;; 4
   "󰲨"      ;; 5
   "󰲪"      ;; 6
   "󰲬"      ;; 7
   "󰲮"      ;; 8
   "󰲰"      ;; 9
   "󰲲"]     ;; 10+ — overflow count > 9
  "Nerd Font icons for the overflow tab indicator.")

(defun my/ct--overflow-str (count)
  "Return \" ICON\" for COUNT hidden tabs."
  (format " %s" (aref my/ct--overflow-icons (min count 10))))

(defface my/ct-modified
  '((t (:foreground "#ff4400")))
  "Face for the modified marker."
  :group 'MRU-tabs)

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 2 — Buffer grouping & categories                  ║
;; ╚══════════════════════════════════════════════════════════════╝

(defvar my/tab-group-categories
  '(("Code"    ""   emacs-lisp-mode lisp-mode python-mode go-mode
               rust-mode java-mode c-mode c++-mode c-ts-mode
               c++-ts-mode javascript-mode js-mode js2-mode
               typescript-mode tsx-mode css-mode web-mode
               nix-mode sh-mode bash-mode yaml-mode json-mode sql-mode)
    ("Grease"  "󰏇"   grease-mode)
    ("Docs"    ""   org-mode markdown-mode text-mode)
    ("Config"  ""   conf-mode)
    ("Dired"   "󰙅"   dired-mode)
    ("Eat"     ""   eat-mode)
    ("Tools"   ""   magit-mode vterm-mode
               help-mode apropos-mode Info-mode)
    ("Buffers" ""))
  "Tab group categories.  Each entry: (NAME ICON MODE...).")

(defun my/tab-group-for-buffer (&optional buffer)
  "Return list containing group name for BUFFER, or nil if excluded."
  (with-current-buffer (or buffer (current-buffer))
    (let ((mode major-mode)
          (bname (buffer-name)))
      (when (and (not (string-prefix-p " " bname))        ; OPEN 1 (when)
                 (not (member bname '("*scratch*" "*Messages*"))))
        (catch 'found                                      ; OPEN 1 (catch)
          (dolist (cat my/tab-group-categories)            ; OPEN 1 (dolist)
            (when (and (cddr cat)                          ; OPEN 1 (when)
                       (memq mode (cddr cat)))
              (throw 'found (list (car cat)))))            ; OPEN 1 (throw) CLOSE 1
          (when-let ((catch-all                             ; OPEN 1 (when-let)
                     (assoc "Buffers" my/tab-group-categories)))
            (list (car catch-all))))))))                   ; OPEN 1 (list) CLOSE 3

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 3 — Per-window data (window parameter, copy-once) ║
;; ╚══════════════════════════════════════════════════════════════╝

;; Each window gets its own data via window-parameter.
;; All reads are immediately copy-tree'd to eliminate any chance
;; of cons-cell sharing between windows.

(defun my/ct--get-data (&optional window)
  "Return the tab-data plist for WINDOW."
  (or (copy-tree (window-parameter (or window (selected-window)) 'my/MRU-tabs-data))
      (list :groups nil :selected nil :mru nil :scroll nil)))

(defun my/ct--put-data (plist &optional window)
  "Store PLIST as tab data for WINDOW."
  (set-window-parameter (or window (selected-window)) 'my/MRU-tabs-data
                        (copy-tree plist)))

(defun my/ct--groups (&optional window)
  (plist-get (my/ct--get-data window) :groups))

(defun my/ct--selected (&optional window)
  (plist-get (my/ct--get-data window) :selected))

(defun my/ct--mru (&optional window)
  (plist-get (my/ct--get-data window) :mru))

(defun my/ct--update-window (window)
  "Refresh tab data for WINDOW: add new buffers, promote current, save."
  (let* ((data     (my/ct--get-data window))
         (groups   (or (plist-get data :groups) '()))
         (mru      (or (plist-get data :mru) '()))
         (selected (or (plist-get data :selected) '()))
         (all-bufs (my/ct--visible-buffers))
         (win-buf  (window-buffer window)))
    ;; Groups: rebuild from all-bufs (fresh list each time)
    (let ((ng '()))
      (dolist (buf all-bufs)
        (when-let* ((grp (car (my/tab-group-for-buffer buf))))
          (let ((cell (assoc grp ng)))
            (if cell
                (setcdr cell (append (cdr cell) (list buf)))
              (push (cons grp (list buf)) ng)))))
      (setq groups ng))
    ;; MRU: keep stored order, filter killed, append new, promote current
    (setq mru (cl-remove-if (lambda (c) (null (cdr c)))
              (mapcar (lambda (c)
                        (cons (car c)
                              (cl-remove-if-not #'buffer-live-p (cdr c))))
                      mru)))
    (dolist (buf all-bufs)
      (when-let* ((grp (car (my/tab-group-for-buffer buf))))
        (let ((mcell (assoc grp mru)))
          (if mcell
              (unless (memq buf (cdr mcell))
                (setcdr mcell (append (cdr mcell) (list buf))))
            (push (cons grp (list buf)) mru)))))
    (setq mru (cl-remove-if (lambda (c) (null (cdr c))) mru))
    (let* ((win-group (car (my/tab-group-for-buffer win-buf)))
           (mcell (and win-group (assoc win-group mru))))
      (when (and mcell (memq win-buf (cdr mcell)))
        (let ((rest (delq win-buf (cdr mcell))))
          (setcdr mcell (cons win-buf rest)))))
    ;; Selection
    (let ((win-group (car (my/tab-group-for-buffer win-buf))))
      (setq selected (mapcar
                      (lambda (gcell)
                        (let* ((g (car gcell))
                               (pref (if (and win-group (equal g win-group)
                                              (memq win-buf (cdr gcell)))
                                         win-buf (car (cdr gcell)))))
                          (cons g pref)))
                      groups)))
    ;; Save with copy-tree for complete isolation
    (my/ct--put-data (list :groups groups :selected selected :mru mru :scroll nil) window)));; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 4 — Buffer list + group maintenance               ║
;; ╚══════════════════════════════════════════════════════════════╝

(defun my/ct--visible-buffers ()
  "Return all visible (non-excluded, live) buffers in buffer-list order."
  (delq nil                                                              ; OPEN 1 (delq)
        (mapcar (lambda (b)                                              ; OPEN 1 (mapcar)
                  (when (and (buffer-live-p b)                           ; OPEN 1 (when)
                             (not (string-prefix-p " "                   ; OPEN 1 (not)
                                                   (buffer-name b)))
                             (not (member (buffer-name b)                ; OPEN 1 (not)
                                          '("*scratch*" "*Messages*"))))
                    b))                                                  ; CLOSE 2 (when, mapcar body)
                (buffer-list))))                                         ; CLOSE 1 (mapcar) CLOSE 1 (delq)

(defun my/ct--update-all-windows ()
  "Refresh tab data for every live window."
  (dolist (win (window-list))                                           ; OPEN 1 (dolist)
    (when (window-live-p win)                                           ; OPEN 1 (when)
      (my/ct--update-window win))))                                     ; CLOSE 2 (when, dolist)

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 5 — Tab rendering (completely self-built)         ║
;; ╚══════════════════════════════════════════════════════════════╝

(defun my/ct--tab-label (buffer selected-p)
  "Return a propertized tab label string for BUFFER.
SELECTED-P non-nil means this is the selected tab."
  (let* ((bufname  (buffer-name buffer))
         (modified (and (buffer-modified-p buffer)                       ; OPEN 2 (let*, and)
                        (not (with-current-buffer buffer                 ; OPEN 1 (with-current-buffer)
                               (derived-mode-p 'vterm-mode)))))
         (prefix   (if modified                                          ; OPEN 1 (if)
                      (propertize "󰐗 " 'face 'my/ct-modified)
                    ""))                                                 ; CLOSE 1 (if)
         (label    (format " %s%s" prefix bufname)))                 ; OPEN 1 (format)
    (propertize label                                                  ; OPEN 1 (propertize)
                'face (if selected-p
                          'my/ct-tab-selected
                        'my/ct-tab-unselected))))                       ; CLOSE 2 (propertize, let*)

(defun my/ct--tab-face (selected-p)
  "Return the face for a tab.  SELECTED-P non-nil for the selected tab."
  (if selected-p 'my/ct-tab-selected 'my/ct-tab-unselected))

(defun my/ct--render-tabbar (window)
  "Build the tab bar header for WINDOW.  Returns a list of strings.
Initializes window data on first call (e.g., after split).
The MRU is only updated by post-command-hook in the focused window."
  (let* ((raw      (my/ct--get-data window))
         (data     (if (plist-get raw :mru)
                       raw
                     ;; First call for this window — initialize
                     (progn (my/ct--update-window window)
                            (my/ct--get-data window))))
         (groups   (plist-get data :groups))
         (selected (plist-get data :selected))
         (mru      (plist-get data :mru))
         (cur-buf  (window-buffer window))
         (cur-group (car (my/tab-group-for-buffer cur-buf)))
         (cell     (assoc cur-group (or mru groups)))
         (bufs     (cl-remove-if-not #'buffer-live-p (cdr cell)))
         (sel-buf  (cdr (assoc cur-group selected)))
         (tabs     bufs))
    (when tabs
      (let* ((overflow-face 'my/ct-overflow)
             (group-str   (my/ct--group-icon window))
             (icon-width  (if group-str (string-width group-str) 0))
             (avail       (- (window-width window) icon-width))
             ;; Build tab segments: (label-str . sep-str)
             (segments (mapcar (lambda (b)
                                 (let ((sel-p (eq b sel-buf)))
                                   (cons (my/ct--tab-label b sel-p)
                                         (propertize "  " 'face
                                                     (my/ct--tab-face sel-p)))))
                               tabs)))
        ;; Trim rightmost non-selected tabs until everything fits
        ;; (including the overflow indicator that will be appended)
        (let* ((hidden 0)
               (total-w (apply '+ (mapcar (lambda (s)
                                            (+ (string-width (car s))
                                               (string-width (cdr s))))
                                          segments))))
          (while (and (> (+ total-w
                            (string-width (my/ct--overflow-str (1+ hidden))))
                         avail)
                      (> (length segments) 1)
                      (< hidden 999))
            (let ((last-s (car (last segments))))
              (setq total-w (- total-w
                               (string-width (car last-s))
                               (string-width (cdr last-s)))
                    segments (nbutlast segments)
                    hidden    (1+ hidden))))
          ;; Build flat result list, then append overflow indicator if any
          (if (null segments)
              ;; Shouldn't happen, but be safe
              nil
            (let* ((acc (list (car (car segments))))
                   (prev-seg (car segments)))
              (dolist (s (cdr segments))
                (nconc acc (list (cdr prev-seg) (car s)))
                (setq prev-seg s))
              ;; trailing sep for last visible tab
              (nconc acc (list (cdr prev-seg)))
              ;; Add overflow indicator if tabs were hidden
              (when (> hidden 0)
                (let ((overflow-obj (propertize (my/ct--overflow-str hidden)
                                                'face overflow-face)))
                  ;; If even selected tab + overflow won't fit, show 󰘕
                  (if (> (+ (string-width (car (car segments)))
                            (string-width (cdr (car segments)))
                            (string-width (my/ct--overflow-str hidden)))
                         avail)
                      (setq acc (list (propertize "󰘕" 'face overflow-face)))
                    (nconc acc (list overflow-obj)))))
              acc)))))))

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 6 — Group icon rendering                           ║
;; ╚══════════════════════════════════════════════════════════════╝

(defun my/ct--group-icon (&optional window)
  "Return the group icon segment string for WINDOW's buffer.
Format:       42 "
  (let ((win (or window (selected-window)))                              ; OPEN 1 (let)
        (buf (window-buffer (or window (selected-window)))))
    (when-let* ((groups  (my/tab-group-for-buffer buf))                ; OPEN 2 (when-let*, let*)
                (group   (car groups))
                (cat     (assoc group my/tab-group-categories))
                (icon    (cadr cat)))
      (let* ((line-str (format-mode-line '("%l") nil win))             ; OPEN 2 (let*, format-mode-line)
             (line-str (if (stringp line-str) line-str "?"))           ; OPEN 1 (if)
             (face     'my/ct-group-icon))
        (concat                                                        ; OPEN 1 (concat)
         (propertize (format " %s " icon)   'face face)                ; OPEN 1 (propertize)
         (propertize (format " %5s " line-str) 'face face)          ; OPEN 1 (propertize)
         (propertize "" 'face face))))))                              ; OPEN 1 (propertize) CLOSE 5

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 7 — Header-line :eval wrappers                    ║
;; ╚══════════════════════════════════════════════════════════════╝

;; Dynamic variable: bound during header-line :eval so called
;; functions know which window is being rendered.
(defvar my/ct--render-window nil)

(defun my/ct--resolve-window ()
  "Return the window whose header-line is being evaluated."
  (let ((buf (current-buffer))
        (sel (selected-window)))
    (if (eq buf (window-buffer sel))                                    ; OPEN 1 (if)
        sel
      (or (get-buffer-window buf 'visible) sel))))                      ; OPEN 1 (or) CLOSE 2 (if, let)

(defun my/ct--eval-tabbar ()
  ":eval wrapper: binds render-window, builds the tab bar."
  (let ((my/ct--render-window (my/ct--resolve-window)))                 ; OPEN 1 (let)
    (my/ct--render-tabbar my/ct--render-window)))                       ; CLOSE 1 (let)

(defun my/ct--eval-group-icon ()
  ":eval wrapper: binds render-window, builds the group icon."
  (let ((my/ct--render-window (my/ct--resolve-window)))                 ; OPEN 1 (let)
    (my/ct--group-icon my/ct--render-window)))                          ; CLOSE 1 (let)

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 8 — Tab cycling                                    ║
;; ╚══════════════════════════════════════════════════════════════╝

(defun my/ct--cycle (&optional backward)
  "Cycle to the next tab in the current window's MRU list.
With BACKWARD non-nil, cycle to the previous tab."
  (interactive "P")
  (let* ((win   (selected-window))
         (buf   (current-buffer))
         (group (car (my/tab-group-for-buffer buf)))
         (mru   (my/ct--mru win))
         (cell  (and group (assoc group mru)))
         (blist (and cell (cdr cell)))
         (pos   (and blist (cl-position buf blist))))
    (when (and blist pos (functionp #'switch-to-buffer))
      (let* ((len (length blist))
             (idx (if backward
                      (mod (1- pos) len)
                    (mod (1+ pos) len)))
             (next (nth idx blist)))
        (when (buffer-live-p next)
          (switch-to-buffer next t))))))

(defun my/MRU-tabs-forward ()
  "Cycle to the next tab."
  (interactive)
  (my/ct--cycle))

(defun my/MRU-tabs-backward ()
  "Cycle to the previous tab."
  (interactive)
  (my/ct--cycle t))

;; ── Keybindings ─────────────────────────────────────────────
(when (boundp 'MRU-tabs-mode-map)
  (define-key MRU-tabs-mode-map (kbd "<M-tab>") #'my/MRU-tabs-forward)
  (define-key MRU-tabs-mode-map (kbd "C-<tab>") #'my/MRU-tabs-forward)
  (define-key MRU-tabs-mode-map (kbd "C-S-<iso-lefttab>") #'my/MRU-tabs-backward))

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 9 — Activation & hooks                             ║
;; ╚══════════════════════════════════════════════════════════════╝

;; ── Enable MRU-tabs minor mode (for keybindings) ────────
(MRU-tabs-mode t)

;; ── Set our custom header-line-format ──────────────────────
(let ((fmt-var (or (and (boundp 'MRU-tabs-display-line-format)           ; OPEN 2 (let, or)
                        (symbol-value 'MRU-tabs-display-line-format))
                   'header-line-format)))
  (set-default fmt-var                                                 ; OPEN 1 (set-default)
               (list                                                   ; OPEN 1 (list)
                '(:eval (my/ct--eval-group-icon))                      ; OPEN 1 (:eval)
                '(:eval (my/ct--eval-tabbar)))))                       ; OPEN 2 (:eval, list) CLOSE 2

;; ── Window deletion cleanup ─────────────────────────────────
(add-hook 'window-deletions-functions
          (lambda (win)
            (set-window-parameter win 'my/MRU-tabs-data nil)))

;; ── Post-command live update ────────────────────────────────
(defun my/ct--force-update ()
  "Refresh tab data, force redisplay on post-command-hook."
  (when (and MRU-tabs-mode (not (minibufferp)))
    (my/ct--update-window (selected-window))
    (force-window-update (selected-window))))

(add-hook 'post-command-hook #'my/ct--force-update)

;; ── Initial update ──────────────────────────────────────────
(my/ct--update-all-windows)
(force-window-update)

;; ╔══════════════════════════════════════════════════════════════╗
;; ║  SECTION 9 — Tab label (for MRU-tabs package fallback)  ║
;; ╚══════════════════════════════════════════════════════════════╝

;; Keep this function defined in case other code references it,
;; but it's NOT used by our v4 rendering (my/ct--tab-label replaces it).
(defun my/MRU-tabs-tab-label (tab)
  "Legacy tab label function — NOT used by v4 rendering."
  (let* ((buf (car tab))
         (bufname (buffer-name buf))
         (modified (buffer-modified-p buf))
         (prefix (if modified (propertize "󰑧 " 'face 'my/ct-modified) "")))
    (format " %s%s " prefix bufname)))

(provide 'MRU-tabs)
;; MRU-tabs.el ends here
