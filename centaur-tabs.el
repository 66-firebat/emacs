;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  centaur-tabs.el — Centaur Tabs Configuration
;;
;;  Aesthetic, modern-looking tab bar at the top of each frame/window.
;;  Integrates with the firebat theme and Nerd Font icons.
;;  Designed for terminal (-nw) use with Evil keybindings.
;; =============================================================================

(use-package centaur-tabs
  :demand t
  :config
  ;; ── Core enable ──────────────────────────────────────────────
  (centaur-tabs-mode t)
  (centaur-tabs-headline-match)

  ;; ── Tab line format ──────────────────────────────────────────
  (let ((fmt-var (symbol-value 'centaur-tabs-display-line-format)))
    (set-default fmt-var
                 `((:eval (my/centaur-tabs-group-icon))
                   (:eval (my/centaur-tabs-line)))))

  ;; ── Tab label ──────────────────────────────────────────────
  (setq centaur-tabs-tab-label-function 'my/centaur-tabs-tab-label)
  (setq centaur-tabs-style "bar")
  (setq centaur-tabs-set-icons nil)
  (setq centaur-tabs-plain-icons nil)
  (setq centaur-tabs-gray-out-icons 'buffer)
  (setq centaur-tabs-set-bar nil)
  (setq centaur-tabs-left-edge-margin "")
  (setq centaur-tabs-right-edge-margin "")
  (setq centaur-tabs-set-close-button nil)
  (setq centaur-tabs-set-modified-marker nil)
  (setq centaur-tabs-height 24)
  (setq centaur-tabs-bar-height (+ 8 centaur-tabs-height))
  (setq centaur-tabs-show-new-tab-button nil)

  ;; ── Buffer grouping ──────────────────────────────────────────
  (defvar my/tab-group-categories
    '(("Code"    ""   emacs-lisp-mode lisp-mode python-mode go-mode
                 rust-mode java-mode c-mode c++-mode c-ts-mode
                 c++-ts-mode javascript-mode js-mode js2-mode
                 typescript-mode tsx-mode css-mode web-mode
                 nix-mode sh-mode bash-mode yaml-mode json-mode
                 sql-mode)
      ("Docs"    ""   org-mode markdown-mode text-mode)
      ("Config"  ""   conf-mode)
      ("Tools"   ""   dired-mode magit-mode eat-mode vterm-mode
                 help-mode apropos-mode Info-mode)
      ("Buffers" ""))
    "Tab group categories.  Each entry is (CATEGORY ICON MODE ...).
The \"Buffers\" entry is a catch-all for unmatched modes.")

  (defun my/tab-group-for-buffer (&optional buffer)
    "Return the group name for BUFFER, or nil if excluded."
    (with-current-buffer (or buffer (current-buffer))
      (let ((mode major-mode)
            (bname (buffer-name)))
        (when (and (not (string-prefix-p " " bname))
                   (not (member bname '("*scratch*" "*Messages*"))))
          (catch 'found
            (dolist (cat my/tab-group-categories)
              (when (and (cddr cat) (memq mode (cddr cat)))
                (throw 'found (car cat))))
            (when-let ((catch-all (assoc "Buffers" my/tab-group-categories)))
              (car catch-all)))))))

  ;; ── Tab ordering: current buffer always leftmost (MRU) ─────
  (defun my/tab-buffer-list ()
    "Return all buffers in the same group as the current buffer."
    (let* ((cur (current-buffer))
           (group (my/tab-group-for-buffer cur)))
      (when group
        (let* ((filtered (delq nil
                               (mapcar (lambda (b)
                                         (when (and (buffer-live-p b)
                                                    (eq (my/tab-group-for-buffer b) group))
                                           b))
                                       (buffer-list))))
               (pos (cl-position cur filtered)))
          (when pos
            (cons cur (nthcdr (1+ pos) filtered)))))))

  (setq centaur-tabs-buffer-list-function #'my/tab-buffer-list)
  (setq centaur-tabs-cycle-scope 'tabs)

  ;; ── MRU sort helper ─────────────────────────────────────────
  (defun my/centaur-tabs--sort-tabset-mru (tabset)
    "Sort tabs in TABSET into MRU order. Current buffer first."
    (let* ((cur (current-buffer))
           (tabs (symbol-value tabset))
           (mru (seq-filter
                 (lambda (b)
                   (and (buffer-live-p b)
                        (cl-find b tabs :key #'car)))
                 (buffer-list)))
           (ordered
            (delq nil
                  (mapcar (lambda (b)
                            (cl-find b tabs :key #'car))
                          mru))))
      (when ordered
        (set tabset ordered)
        (centaur-tabs-set-template tabset nil))))

  ;; ── Per-window tab ordering state ───────────────────────────
  ;; Each window tracks its own buffer order independently.

  (defvar my/centaur-tabs--window-state (make-hash-table :test 'eq)
    "Hash table window → ((GROUP-NAME . (BUFFER ...)) ...).
Each window stores its own ordered buffer list per group.")

  (defun my/centaur-tabs--on-window-deleted (window)
    "Clean up per-window state for deleted WINDOW."
    (remhash window my/centaur-tabs--window-state))
  (add-hook 'window-deletions-functions #'my/centaur-tabs--on-window-deleted)

  ;; ── Before rendering: use per-window ordering ──────────────
  (defun my/centaur-tabs--reorder-tabset-mru (orig-fn)
    "Around advice for `centaur-tabs-line'.
Each window has its OWN independent tab order.  The global tabset
value is temporarily set to this window's order for rendering."
    (let* ((tabset (centaur-tabs-current-tabset t))
           (global-vals (and tabset (symbol-value tabset)))
           (win (selected-window))
           (cur (current-buffer))
           (group (and tabset (symbol-name tabset)))
           (state (gethash win my/centaur-tabs--window-state))
           (pw-entry (and state group (assoc group state)))
           (pw-buffers (and pw-entry (cdr pw-entry)))
           pw-tabs)
      (when (and tabset group global-vals)
        ;; Initialize per-window state from global on first access
        (unless pw-buffers
          (setq pw-buffers (mapcar #'car global-vals))
          (let ((new-entry (cons group pw-buffers)))
            (if state
                (setcdr state (cons new-entry (cdr state)))
              (puthash win (list new-entry) my/centaur-tabs--window-state))))
        ;; Sync: add buffers from global, remove killed buffers
        (dolist (tab global-vals)
          (let ((buf (car tab)))
            (unless (memq buf pw-buffers)
              (setq pw-buffers (nconc pw-buffers (list buf))))))
        (setq pw-buffers (cl-remove-if-not
                          (lambda (b) (and (buffer-live-p b)
                                           (cl-find b global-vals :key #'car)))
                          pw-buffers))
        ;; Sort to MRU: current buffer first, rest by (buffer-list)
        (let* ((ordered (cons cur (cl-remove-if (lambda (b) (eq b cur)) pw-buffers)))
               (final (delq nil
                            (mapcar (lambda (b)
                                      (when (memq b pw-buffers) b))
                                    ordered))))
          (setq pw-buffers final)
          ;; Update per-window state
          (let ((entry (assoc group (gethash win my/centaur-tabs--window-state))))
            (when entry (setcdr entry pw-buffers)))
          ;; Convert to tab cons cells for centaur-tabs
          (setq pw-tabs (delq nil
                              (mapcar (lambda (b)
                                        (cl-find b global-vals :key #'car))
                                      pw-buffers)))
          (when pw-tabs
            ;; Set global tabset to per-window order for rendering
            (set tabset (copy-tree pw-tabs))
            (centaur-tabs-set-template tabset nil)
            (centaur-tabs-select-tab-value (current-buffer) tabset)
            ;; Debug
            (message "CT: win=%s cur=%s pw=%s"
                     (sxhash win)
                     (buffer-name cur)
                     (mapconcat #'buffer-name pw-buffers ", "))))
        (funcall orig-fn))))

  (advice-remove 'centaur-tabs-line #'my/centaur-tabs--reorder-tabset)
  (advice-add 'centaur-tabs-line :around #'my/centaur-tabs--reorder-tabset-mru)

  ;; ── Apply colors with overflow truncation ──────────────────
  (defun my/centaur-tabs--apply-gradient (orig-fn tabset)
    "Apply uniform colors and truncate overflowing tabs."
    (let* ((result (funcall orig-fn tabset))
           (tabs (and tabset (symbol-value tabset)))
           (bg-color "#5C5C5C")
           (fg-color "#2b2b2b"))
      (when (and (consp result) (nth 2 result) tabs)
        (let ((elts (nth 2 result)))
          ;; Apply colours to all tab text strings.
          ;; Selected tab gets a slightly lighter background.
          (cl-loop for i from 0
                   for elt in elts
                   for tab in tabs
                   do (let* ((selected (centaur-tabs-selected-p tab tabset))
                             (bg (if selected "#8C8C8C" bg-color))
                             (stripped (if (string-suffix-p " " elt)
                                           (substring elt 0 -1) elt)))
                        (setf (nth i elts)
                              (propertize stripped 'face
                                          (list :background bg :foreground fg-color)))))
          ;; Build result-elts with separators.
          (let* ((sel-bg "#8C8C8C")
                 (first-tab-bg (if (and tabs (centaur-tabs-selected-p (car tabs) tabset))
                                   sel-bg bg-color))
                 (result-elts (list (car elts)
                                    (propertize " " 'face
                                                (list :background first-tab-bg :foreground fg-color)))))
            (cl-loop for i from 1 for elt in (cdr elts)
                     for tab in (cdr tabs)
                     do (let ((tab-bg (if (centaur-tabs-selected-p tab tabset)
                                          sel-bg bg-color)))
                          (nconc result-elts
                                 (list (propertize "" 'face (list :background tab-bg :foreground fg-color))
                                       elt
                                       (propertize " " 'face
                                                   (list :background tab-bg :foreground fg-color))))))
            ;; ── Terminal width overflow truncation ─────────────
            (when my/centaur-tabs-overflow-adapt
              (let* ((icon-str (my/centaur-tabs-group-icon))
                     (icon-width (if icon-str (string-width icon-str) 0))
                     (avail-width (floor (* (window-width)
                                            my/centaur-tabs-width-factor)))
                     (n-tabs (length tabs))
                     (n-dropped 0)
                     (total-width icon-width))
                (dolist (elt result-elts)
                  (cl-incf total-width (string-width elt)))
                (while (and (> total-width avail-width)
                            (> n-tabs 1)
                            result-elts)
                  (let ((last-three (last result-elts 3)))
                    (when (= (length last-three) 3)
                      (let ((w-sep  (string-width (nth 0 last-three)))
                            (w-tab  (string-width (nth 1 last-three)))
                            (w-trail (string-width (nth 2 last-three))))
                        (setq result-elts (butlast result-elts 3)
                              total-width (- total-width w-sep w-tab w-trail)
                              n-tabs (1- n-tabs)
                              n-dropped (1+ n-dropped))))))
                (when (> n-dropped 0)
                  (let* ((nf-digits [nil "󰲠" "󰲢" "󰲤" "󰲦" "󰲨" "󰲪" "󰲬" "󰲮" "󰲰"])
                         (digit-str (if (<= n-dropped 9)
                                       (aref nf-digits n-dropped)
                                     "󰲲"))
                         (overflow-str (format " %s " digit-str)))
                    (setcar (nthcdr 4 result)
                            (propertize overflow-str
                                        'face 'my/centaur-tabs-overflow-face))))))
            (setq elts result-elts))
          (setf (nth 2 result) elts)))
      result))

  (advice-add 'centaur-tabs-line-format :around #'my/centaur-tabs--apply-gradient)

  (defun my/centaur-tabs-group-icon ()
    "Return group icon + live line number."
    (when-let* ((group (my/tab-group-for-buffer (current-buffer)))
                (entry (assoc group my/tab-group-categories))
                (icon (cadr entry)))
      (let* ((face '(:background "#ff4400" :foreground "#2b2b2b" :weight bold))
             (line (my/centaur-tabs--line-number (current-buffer))))
        (concat (propertize (format " %s " icon) 'face face)
                (propertize (format "  %4s " line) 'face face)
                (propertize "" 'face face)))))

  ;; ── Tab navigation keybindings ───────────────────────────────
  (define-key centaur-tabs-mode-map (kbd "<M-tab>") 'centaur-tabs-forward)
  (define-key centaur-tabs-mode-map (kbd "C-<tab>") 'centaur-tabs-forward)
  (define-key centaur-tabs-mode-map (kbd "C-S-<iso-lefttab>") 'centaur-tabs-backward)

  ;; Clean up previously-registered advice.
  (advice-remove 'centaur-tabs-line #'my/centaur-tabs--trim-tab-trailing)
  (advice-remove 'centaur-tabs-line-format #'my/centaur-tabs--trim-tabs)
  (advice-remove 'centaur-tabs-line #'my/centaur-tabs--reorder-tabset)

  ;; Clear cached template.
  (centaur-tabs-set-template (centaur-tabs-current-tabset) nil)
  (force-window-update (selected-window))
  )

;; ── Group label face ───────────────────────────────────────────
(defface my/centaur-tabs-group-face
  '((t (:foreground "#ff4400" :background "#2b2b2b" :weight bold)))
  "Face for the centaur-tabs group name segment."
  :group 'centaur-tabs)

;; ── Overflow indicator ────────────────────────────────────────
(defvar my/centaur-tabs-width-factor 1.0
  "Multiplier for perceived terminal width.")
(defvar my/centaur-tabs-overflow-adapt t
  "When non-nil, truncate overflowing tabs.")
(defface my/centaur-tabs-overflow-face
  '((t (:foreground "#ff4400" :background "#2b2b2b" :weight bold)))
  "Face for the overflow indicator."
  :group 'centaur-tabs)

;; ── Git branch cache ───────────────────────────────────────────
(defvar my/centaur-tabs--branch-cache (make-hash-table :test 'equal)
  "Hash table mapping project path → git branch name.")
(defvar my/centaur-tabs--last-buffer nil
  "Last buffer for which branch cache was valid.")

(defun my/centaur-tabs--invalidate-branch-cache ()
  "Clear the branch cache when the current buffer changes."
  (unless (eq (current-buffer) my/centaur-tabs--last-buffer)
    (clrhash my/centaur-tabs--branch-cache)
    (setq my/centaur-tabs--last-buffer (current-buffer))))

(defun my/centaur-tabs--git-info (project-path)
  "Return \"branch:hash\" for PROJECT-PATH, or \"󱃓\" on failure."
  (let ((cached (gethash project-path my/centaur-tabs--branch-cache 'missing)))
    (if (not (eq cached 'missing)) cached
      (let ((result
             (condition-case nil
                 (let* ((branch-str
                         (with-output-to-string
                           (with-current-buffer standard-output
                             (call-process "git" nil '(t nil) nil
                                           "-C" project-path
                                           "rev-parse" "--abbrev-ref" "HEAD"))))
                        (hash-str
                         (with-output-to-string
                           (with-current-buffer standard-output
                             (call-process "git" nil '(t nil) nil
                                           "-C" project-path
                                           "rev-parse" "--short" "HEAD")))))
                   (setq branch-str (string-trim branch-str)
                         hash-str   (string-trim hash-str))
                   (if (or (string-empty-p branch-str)
                           (string= branch-str "HEAD")
                           (string-empty-p hash-str))
                       "󱃓"
                     (format "%s:%s" branch-str hash-str)))
               (error "󱃓"))))
        (puthash project-path result my/centaur-tabs--branch-cache)
        result))))

;; ── Tab label ─────────────────────────────────────────────────
(defun my/centaur-tabs-tab-label (tab)
  "Return a label for TAB.  Modified buffers get 󰐗 prefix (in #ff4400)."
  (let* ((tabset (centaur-tabs-current-tabset))
         (selected-p (and tabset (centaur-tabs-selected-p tab tabset)))
         (buf (car tab))
         (bufname (buffer-name buf))
         (modified (and (buffer-modified-p buf)
                        (not (with-current-buffer buf
                               (derived-mode-p 'vterm-mode)))))
         (prefix (if modified
                    (propertize "󰐗 " 'face '(:foreground "#ff4400"))
                  "")))
    (if selected-p
        (format " %s%s" prefix bufname)
      (format " %s%s " prefix bufname))))

;; ── Line number cache ─────────────────────────────────────────
(defvar my/centaur-tabs--line-cache (make-hash-table :test 'eq)
  "Hash table mapping buffer → last-known line number string.")

(defun my/centaur-tabs--line-number (buf)
  "Return the line number string for BUF."
  (if (eq buf (current-buffer))
      (let ((live (format-mode-line '("%l"))))
        (puthash buf live my/centaur-tabs--line-cache)
        live)
    (gethash buf my/centaur-tabs--line-cache "󱃓")))

;; ── Live update — force tab bar redisplay on every command ────
(defun my/centaur-tabs--force-update ()
  "Force tab bar redisplay."
  (when (and centaur-tabs-mode (not (minibufferp)))
    (centaur-tabs-buffer-update-groups)
    (let ((tabset (centaur-tabs-current-tabset)))
      (when tabset
        (centaur-tabs-set-template tabset nil)))
    (force-window-update (selected-window))))

(add-hook 'post-command-hook #'my/centaur-tabs--force-update)

;; ── Trim trailing space ───────────────────────────────────────
(defun my/centaur-tabs-line ()
  "Like `centaur-tabs-line' but without trailing spaces on tab strings."
  (let ((fmt (centaur-tabs-line)))
    (when (consp fmt)
      (let ((tabs (nth 2 fmt)))
        (when (consp tabs)
          (setcar (nthcdr 2 fmt)
                  (mapcar (lambda (s)
                            (if (stringp s) (string-trim-right s) s))
                          tabs)))))
    fmt))

;; ── Label construction ─────────────────────────────────────────
(defun my/centaur-tabs-group-name ()
  "Return a propertized string showing the current centaur-tabs group."
  (my/centaur-tabs--invalidate-branch-cache)
  (let* ((group (or (centaur-tabs-buffer-groups-result)
                    centaur-tabs-common-group-name))
         (tooltip (format "Current group: %s" group))
         (label
          (if (string-match "^Project: \\(.+\\)" group)
              (let* ((proj-path (match-string 1 group))
                     (info      (my/centaur-tabs--git-info proj-path)))
                (if (string= info "󱃓")
                    (format " %s " info)
                  (format "  %s " info)))
            (let ((icon (cond ((string-match-p "Elisp" group)   "")
                              ((string-match-p "Magit" group)   "")
                              ((string-match-p "^Shell$" group) "")
                              ((string-match-p "^EShell$" group) "")
                              ((string-match-p "Dired" group)   "")
                              ((string-match-p "Org" group)     "")
                              ((string-match-p "^Emacs$" group) "")
                              (t ""))))
              (format " %s %s " icon group)))))
    (if (and group (not (string-empty-p group)))
        (propertize label
                    'face 'my/centaur-tabs-group-face
                    'pointer centaur-tabs-mouse-pointer
                    'help-echo tooltip)
      (propertize " ∅ " 'face 'my/centaur-tabs-group-face))))

(provide 'centaur-tabs)
;; centaur-tabs.el ends here
