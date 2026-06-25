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
  ;; Override the default display-line format: group icon box
  ;; followed by our custom tab line function.
  (let ((fmt-var (symbol-value 'centaur-tabs-display-line-format)))
    (set-default fmt-var
                 `((:eval (my/centaur-tabs-group-icon))
                   (:eval (my/centaur-tabs-line)))))

  ;; ── Tab label — active/inactive indicator ──────────────────
  ;; Each tab is prepended with  (active) or  (inactive) so
  ;; you can tell at a glance which window's tab bar is focused.
  (setq centaur-tabs-tab-label-function 'my/centaur-tabs-tab-label)

  ;; ── Tab style (terminal-friendly) ────────────────────────────
  ;; "bar" is cleanest in terminal; "rounded", "chamfer", "slant"
  ;; also work.  Avoid "wave" and "zigzag" in -nw mode.
  (setq centaur-tabs-style "bar")



  ;; ── File icons (handled inside the custom label function) ───
  ;; Built-in icon rendering is disabled — the active/inactive
  ;; indicator (/) is prepended before the Nerd Font file icon
  ;; inside `my/centaur-tabs-tab-label' so the order is:
  ;;     statuscolumn.el   (not    statuscolumn.el)
  (setq centaur-tabs-set-icons nil)
  (setq centaur-tabs-plain-icons nil)
  (setq centaur-tabs-gray-out-icons 'buffer)

  ;; ── Selected-tab indicator bar ───────────────────────────────
  (setq centaur-tabs-set-bar nil)           ;; No active tab bar

  ;; ── Edge margins — remove default leading/trailing spaces ──
  ;; centaur-tabs-left/right-edge-margin default to " " which adds
  ;; unwanted padding on every tab.  Set to empty to eliminate it.
  (setq centaur-tabs-left-edge-margin "")
  (setq centaur-tabs-right-edge-margin "")

  ;; ── Close button & modified marker ───────────────────────────
  ;; Built-in marker (⏺) is disabled.  The modified indicator 󱍸
  ;; is handled inside `my/centaur-tabs-tab-label' instead.
  (setq centaur-tabs-set-close-button nil)
  (setq centaur-tabs-set-modified-marker nil)

  ;; ── Tab height (terminal-friendly) ───────────────────────────
  (setq centaur-tabs-height 24)
  (setq centaur-tabs-bar-height (+ 8 centaur-tabs-height))

  ;; ── New-tab button — disabled; replaced by overflow indicator ─
  (setq centaur-tabs-show-new-tab-button nil)

  ;; ── Buffer grouping & ordering ───────────────────────────────
  ;; Group buffers by major-mode category.  Each group maintains a
  ;; creation-ordered list.  The current buffer is always the
  ;; leftmost tab, followed by up to 6 buffers spawned after it.


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
          ;; Check explicit categories (modes start at 3rd element)
          (catch 'found
            (dolist (cat my/tab-group-categories)
              (when (and (cddr cat) (memq mode (cddr cat)))
                (throw 'found (car cat))))
            ;; Catch-all: "Buffers"
            (when-let ((catch-all (assoc "Buffers" my/tab-group-categories)))
              (car catch-all)))))))

  ;; Tab ordering: current buffer is always leftmost.  Subsequent tabs
  ;; are the most-recently-accessed buffers in the same group, in MRU
  ;; order (Emacs' native (buffer-list) ordering).

  (defun my/tab-buffer-list ()
    "Return all buffers in the same group as the current buffer.
Current buffer leftmost, followed by remaining same-group buffers
in MRU order (from `buffer-list')."
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

  ;; ── MRU tab ordering ─────────────────────────────────────────
  ;; The current buffer is always the leftmost tab, followed by
  ;; the remaining tabs in most-recently-accessed (MRU) order.
  ;; Two advices ensure this:
  ;;
  ;; 1. On centaur-tabs-buffer-update-groups — re-sorts tabsets
  ;;    to MRU after centaur-tabs rebuilds them alphabetically.
  ;; 2. On centaur-tabs-line — re-sorts the current tabset to MRU
  ;;    right before rendering (catch-all / safety net).

  (defun my/centaur-tabs--sort-tabset-mru (tabset)
    "Sort tabs in TABSET into MRU order.
Current buffer first, rest by (buffer-list) order."
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

  (defun my/centaur-tabs--after-update-groups (orig-fn)
    "Wrap `centaur-tabs-buffer-update-groups' to re-sort tabsets
into MRU order after centaur-tabs rebuilds them alphabetically."
    (let ((result (funcall orig-fn)))
      ;; Re-sort every tabset into MRU order
      (dolist (buf (buffer-list))
        (let* ((group (my/tab-group-for-buffer buf))
               (tabset (and group (centaur-tabs-get-tabset group))))
          (when tabset
            (my/centaur-tabs--sort-tabset-mru tabset))))
      result))

  (defun my/centaur-tabs--reorder-tabset-mru (orig-fn)
    "Around advice for `centaur-tabs-line'.
Re-sort the current tabset into MRU order right before rendering."
    (let* ((tabset (centaur-tabs-current-tabset t)))
      (when tabset
        (my/centaur-tabs--sort-tabset-mru tabset)))
    (funcall orig-fn))

  (advice-add 'centaur-tabs-buffer-update-groups
              :around #'my/centaur-tabs--after-update-groups)
  (advice-remove 'centaur-tabs-line #'my/centaur-tabs--reorder-tabset)
  (advice-add 'centaur-tabs-line :around #'my/centaur-tabs--reorder-tabset-mru)

  ;; Apply gradient colors AFTER centaur-tabs has applied its own faces.
  ;; This overrides the face on the final propertized strings.
  (defun my/centaur-tabs--apply-gradient (orig-fn tabset)
    "Replace centaur-tabs' tab faces with gradient colours.
Then truncate overflowing tabs and replace the new-tab button
with a +N overflow indicator."
    (let* ((result (funcall orig-fn tabset))
           (tabs (and tabset (symbol-value tabset)))
           (colors ["#D4D4D4" "#BCBCBC" "#A4A4A4" "#8C8C8C" "#747474" "#5C5C5C"]))
      (when (and (consp result) (nth 2 result) tabs)
        (let ((elts (nth 2 result)))
          ;; Apply gradient colours to ALL tabs (no 6-tab limit)
          (cl-loop for i from 0
                   for elt in elts
                   for tab in tabs
                   do (let* ((bg (aref colors (min i 5)))
                             (stripped (if (string-suffix-p " " elt)
                                           (substring elt 0 -1) elt)))
                        (setf (nth i elts)
                              (propertize stripped 'face
                                          (list :background bg :foreground "#2b2b2b")))))
          ;; Build result-elts with separators (all tabs, no limit)
          (let ((result-elts (list (car elts)
                                  (propertize " " 'face
                                              (list :background (aref colors 0) :foreground "#2b2b2b")))))
            (cl-loop for i from 1 for elt in (cdr elts)
                     do (let* ((c (aref colors (min i 5))))
                          (nconc result-elts
                                 (list (propertize "" 'face (list :background c :foreground "#2b2b2b"))
                                       elt
                                       (propertize " " 'face
                                                   (list :background c :foreground "#2b2b2b"))))))
            ;; ── Terminal width overflow truncation ─────────────
            ;; Measure total width of group-icon + all tab elts.
            ;; Drop rightmost tabs until it fits, showing +N.
            (when my/centaur-tabs-overflow-adapt
              (let* ((icon-str (my/centaur-tabs-group-icon))
                     (icon-width (if icon-str (string-width icon-str) 0))
                     (avail-width (floor (* (window-width)
                                            my/centaur-tabs-width-factor)))
                     (n-tabs (length tabs))
                     (n-dropped 0)
                     (total-width icon-width))
                ;; Measure total width of all result-elts
                (dolist (elt result-elts)
                  (cl-incf total-width (string-width elt)))
                ;; Drop tabs from the right until it fits or only 1 left
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
                ;; Add +N indicator if any tabs were dropped
                (when (> n-dropped 0)
                  (let ((overflow-str (format " 󰍌 %d " n-dropped)))
                    ;; Place overflow indicator at slot 4 (replacing new-tab button)
                    (setcar (nthcdr 4 result)
                            (propertize overflow-str
                                        'face 'my/centaur-tabs-overflow-face))))))
            (setq elts result-elts))
          (setf (nth 2 result) elts)))
      result))

  (advice-add 'centaur-tabs-line-format :around #'my/centaur-tabs--apply-gradient)

  (defun my/centaur-tabs-group-icon ()
    "Return group icon + live line number + active tab indicator.
All use the same fixed colors (orange bg, dark fg, bold)."
    (when-let* ((group (my/tab-group-for-buffer (current-buffer)))
                (entry (assoc group my/tab-group-categories))
                (icon (cadr entry)))
      (let* ((face '(:background "#ff4400" :foreground "#2b2b2b" :weight bold))
             (line (my/centaur-tabs--line-number (current-buffer))))
        (concat (propertize (format " %s " icon) 'face face)
                (propertize (format "  %4s " line) 'face face)
                (propertize "" 'face face)))))



  ;; ── Tab navigation keybindings ───────────────────────────────
  ;; Non-Evil bindings for tab cycling (works from any state).
  (define-key centaur-tabs-mode-map (kbd "<M-tab>") 'centaur-tabs-forward)
  (define-key centaur-tabs-mode-map (kbd "C-<tab>") 'centaur-tabs-forward)
  (define-key centaur-tabs-mode-map (kbd "C-S-<iso-lefttab>") 'centaur-tabs-backward)

  ;; Clean up any previously-registered advice from earlier
  ;; versions of this file.
  (advice-remove 'centaur-tabs-line #'my/centaur-tabs--trim-tab-trailing)
  (advice-remove 'centaur-tabs-line-format #'my/centaur-tabs--trim-tabs)
  (advice-remove 'centaur-tabs-line #'my/centaur-tabs--reorder-tabset)

  ;; Clear any cached template so the next redisplay rebuilds it
  ;; from scratch with the new wrapper.
  (centaur-tabs-set-template (centaur-tabs-current-tabset) nil)
  (force-window-update (selected-window))

  ;; ── Additional convenience commands ──────────────────────────
  ;; Jump to a tab by typing a displayed character (ace-jump style)
  ;; Bound to SPC . in the leader key, but available here too:
  ;; (centaur-tabs-ace-jump)
  )

;; ── Group label segment ─────────────────────────────────────────
;; Prepend the current tab group name (with icon) at the leftmost
;; edge of the centaur-tabs bar, so you always know which group the
;; current buffer belongs to at a glance.
;;
;; This is called from the display-line-format as an :eval form,
;; so it runs on every redisplay — project branch lookups are
;; cached and only refreshed on buffer switches.

;; ── Group label face ───────────────────────────────────────────
;; defface ensures the face exists with proper defaults before the
;; firebat theme overrides it via custom-theme-set-faces in theme.el.

(defface my/centaur-tabs-group-face
  '((t (:foreground "#ff4400" :background "#2b2b2b" :weight bold)))
  "Face for the centaur-tabs group name segment."
  :group 'centaur-tabs)

;; ── Overflow indicator ────────────────────────────────────────

(defvar my/centaur-tabs-width-factor 1.0
  "Multiplier for perceived terminal width.
The effective width for tab overflow calculations is
(* (window-width) `my/centaur-tabs-width-factor').
Set to a value lower than 1.0 to reserve space at the right edge.")

(defvar my/centaur-tabs-overflow-adapt t
  "When non-nil, tabs that overflow the terminal width are
truncated and a +N overflow indicator is shown.")

(defface my/centaur-tabs-overflow-face
  '((t (:foreground "#ff4400" :background "#2b2b2b" :weight bold)))
  "Face for the +N overflow indicator."
  :group 'centaur-tabs)

;; ── Git branch cache ───────────────────────────────────────────
;; Invalidate the cache whenever the current buffer changes so that
;; git is only invoked once per buffer switch, not on every redraw.

(defvar my/centaur-tabs--branch-cache (make-hash-table :test 'equal)
  "Hash table mapping project path → git branch name.
Cleared on buffer switch.")

(defvar my/centaur-tabs--last-buffer nil
  "Last buffer for which `my/centaur-tabs--branch-cache' was valid.")

(defun my/centaur-tabs--invalidate-branch-cache ()
  "Clear the branch cache when the current buffer changes."
  (unless (eq (current-buffer) my/centaur-tabs--last-buffer)
    (clrhash my/centaur-tabs--branch-cache)
    (setq my/centaur-tabs--last-buffer (current-buffer))))

(defun my/centaur-tabs--git-info (project-path)
  "Return \"branch:hash\" for PROJECT-PATH, or \"󱃓\" on failure.
Result is cached per project path."
  (let ((cached (gethash project-path my/centaur-tabs--branch-cache 'missing)))
    (if (not (eq cached 'missing))
        cached
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

;; ── Tab label — active tab separator only ─────────────────────
;; The active tab gets │ on both sides.  No active/inactive
;; indicator icons.

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
;; Active tab shows live line number; inactive tabs show a cached
;; stale value.  Only the active buffer's line number updates in
;; real time as the cursor moves.

(defvar my/centaur-tabs--line-cache (make-hash-table :test 'eq)
  "Hash table mapping buffer \\→ last-known line number string.
Inactive tabs display the cached value so the number stays stale
until the buffer becomes active again.")

(defun my/centaur-tabs--line-number (buf)
  "Return the line number string for BUF.
Active buffer gets the live line number; inactive buffers return
the cached stale value with fallback to 󱃓."
  (if (eq buf (current-buffer))
      ;; Active buffer — compute live, cache it
      (let ((live (format-mode-line '("%l"))))
        (puthash buf live my/centaur-tabs--line-cache)
        live)
    ;; Inactive buffer — use stale cached value
    (gethash buf my/centaur-tabs--line-cache "󱃓")))

;; ── Live update — force tab bar redisplay on every command ────
;; This makes the active tab's line number update in real time as
;; the cursor moves.

(defun my/centaur-tabs--force-update ()
  "Force tab bar redisplay — rebuilds tabset and clears template."
  (when (and centaur-tabs-mode (not (minibufferp)))
    (centaur-tabs-buffer-update-groups)    ;; Rebuild tabsets (no alphabetical sort)
    (let ((tabset (centaur-tabs-current-tabset)))
      (when tabset
        (centaur-tabs-set-template tabset nil)))
    (force-window-update (selected-window))))

(add-hook 'post-command-hook #'my/centaur-tabs--force-update)

;; ── Trim trailing space ───────────────────────────────────────
;; centaur-tabs-line-tab (a defsubst) appends " " to every tab
;; label.  Instead of fighting defsubst inlining, we wrap the
;; display :eval so we can post-process the format list.

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
  "Return a propertized string showing the current centaur-tabs group.

For **Project** groups the label shows   <branch>  (or  󱃓  when the
git branch cannot be determined).  All other groups show their
standard icon and group name (e.g.   Elisp ,   Common ).
The tooltip always shows the full group name."
  (my/centaur-tabs--invalidate-branch-cache)
  (let* ((group (or (centaur-tabs-buffer-groups-result)
                    centaur-tabs-common-group-name))
         (tooltip (format "Current group: %s" group))
         (label
          (if (string-match "^Project: \\(.+\\)" group)
              ;; Project group — show   <branch>  (or  󱃓  on failure)
              (let* ((proj-path (match-string 1 group))
                     (info      (my/centaur-tabs--git-info proj-path)))
                (if (string= info "󱃓")
                    (format " %s " info)
                  (format "  %s " info)))
            ;; Non-project group — show standard icon + group name
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
