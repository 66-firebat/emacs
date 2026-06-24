;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  neoscroll.el — Smooth animated scrolling for terminal Emacs
;;
;;  Bundles the neoscroll library (by Yuantao Wang, GPL-3.0) plus config.
;;  Animated scrolling via easing functions — works in TTY terminals.
;;  Integrates with Evil mode: C-u, C-d, C-f, C-b, C-y, C-e.
;;
;;  Source: https://github.com/0WD0/neoscroll.el
;;
;;  Statuscolumn integration: after each animation step, sc--init is
;;  called to keep jump labels in sync with the scrolled content.
;; =============================================================================

;; ═════════════════════════════════════════════════════════════════════════════
;;  Library code — neoscroll.el v1.0.0 (bundled, no package needed)
;; ═════════════════════════════════════════════════════════════════════════════

(require 'cl-lib)

(defgroup neoscroll nil
  "Smooth scrolling for Emacs inspired by neoscroll.nvim"
  :group 'scrolling :prefix "neoscroll-")

(defcustom neoscroll-mappings
  '("C-u" "C-d" "C-b" "C-f" "C-y" "C-e")
  "Default key mappings for smooth scrolling."
  :type '(repeat string) :group 'neoscroll)

(defcustom neoscroll-hide-cursor nil
  "Hide cursor while scrolling."
  :type 'boolean :group 'neoscroll)

(defcustom neoscroll-stop-eof t
  "Stop at EOF when scrolling downwards."
  :type 'boolean :group 'neoscroll)

(defcustom neoscroll-easing 'sine
  "Default easing function (linear, quadratic, cubic, sine)."
  :type '(choice (const linear) (const quadratic) (const cubic) (const sine))
  :group 'neoscroll)

(defcustom neoscroll-pre-hook nil
  "Function to run before scrolling animation starts."
  :type '(choice function null) :group 'neoscroll)

(defcustom neoscroll-post-hook nil
  "Function to run after scrolling animation ends."
  :type '(choice function null) :group 'neoscroll)

(defcustom neoscroll-scroll-duration 0.15
  "Default duration for C-u/C-d scrolling in seconds."
  :type 'float :group 'neoscroll)

(defcustom neoscroll-page-duration 0.25
  "Default duration for C-f/C-b page scrolling in seconds."
  :type 'float :group 'neoscroll)

(defcustom neoscroll-line-duration 0.025
  "Default duration for C-y/C-e line scrolling in seconds."
  :type 'float :group 'neoscroll)

(defcustom neoscroll-line-step 1
  "Number of lines to scroll with C-y/C-e commands."
  :type 'integer :group 'neoscroll)

(defvar neoscroll--timer nil "Current animation timer")
(defvar neoscroll--active nil "Whether animation is active")
(defvar neoscroll--interrupt-flag nil "Interrupt flag")
(defvar neoscroll--target-line 0 "Target line to scroll to")
(defvar neoscroll--relative-line 0 "Current relative line position")
(defvar neoscroll--total-lines 0 "Total lines to scroll")
(defvar neoscroll--current-opts nil "Current scroll options")
(defvar neoscroll--saved-goal-column nil "Saved goal column")

(defun neoscroll--easing-linear (p) p)
(defun neoscroll--easing-quadratic (p) (* p p))
(defun neoscroll--easing-cubic (p) (- 1 (expt (- 1 p) 3)))
(defun neoscroll--easing-sine (p) (- 1 (cos (* p (/ pi 2)))))

(defun neoscroll--apply-easing (progress easing)
  (pcase easing
    ('linear (neoscroll--easing-linear progress))
    ('quadratic (neoscroll--easing-quadratic progress))
    ('cubic (neoscroll--easing-cubic progress))
    ('sine (neoscroll--easing-sine progress))
    (_ progress)))

(defun neoscroll--interrupt (&rest _)
  (when neoscroll--timer
    (cancel-timer neoscroll--timer)
    (setq neoscroll--timer nil neoscroll--active nil
          neoscroll--interrupt-flag t neoscroll--saved-goal-column nil))
  (when (or (bound-and-true-p hl-line-mode)
            (bound-and-true-p global-hl-line-mode))
    (run-hooks 'post-command-hook)))

(defun neoscroll--check-input ()
  (when (and neoscroll--active (input-pending-p))
    (neoscroll--interrupt) t))

(defun neoscroll--line-pixel-height ()
  (if (display-graphic-p) (line-pixel-height) 1))

(defun neoscroll--compute-time-step (remaining)
  (let* ((range (abs neoscroll--total-lines))
         (dur (or (plist-get neoscroll--current-opts :duration) 0.25))
         (dur-ms (* dur 1000))
         (easing (or (plist-get neoscroll--current-opts :easing) neoscroll-easing)))
    (cond
     ((< remaining 1) 1000)
     ((eq easing 'linear)
      (max 1 (floor (/ dur-ms (max 1 (1- range))))))
     (t
      (let* ((ef (pcase easing
                   ('quadratic (lambda (x) (- 1 (expt (- 1 x) 0.5))))
                   ('cubic (lambda (x) (- 1 (expt (- 1 x) (/ 1.0 3)))))
                   ('sine (lambda (x) (/ (* 2 (asin x)) pi)))
                   (_ (lambda (x) x))))
             (x1 (/ (float (- range remaining)) range))
             (x2 (/ (float (- range (1- remaining))) range))
             (ts (floor (* dur-ms (- (funcall ef x2) (funcall ef x1))))))
        (max 1 ts))))))

(defun neoscroll-scroll (lines &optional opts)
  (let* ((opts (or opts '())) (move-cursor (if (plist-member opts :move-cursor)
                                                (plist-get opts :move-cursor) t))
         (info (plist-get opts :info)))
    (neoscroll--interrupt)
    (unless (zerop lines)
      (when (and (featurep 'evil) move-cursor)
        (setq this-command (if (> lines 0) 'next-line 'previous-line))
        (unless (memq last-command '(next-line previous-line))
          (setq temporary-goal-column
                (cond ((and (boundp 'track-eol) track-eol (eolp) (not (bolp)))
                       most-positive-fixnum)
                      (t (current-column)))))
        (setq neoscroll--saved-goal-column
              (or goal-column temporary-goal-column (current-column))))
      (setq neoscroll--current-opts opts neoscroll--total-lines lines
            neoscroll--target-line lines neoscroll--relative-line 0)
      (when neoscroll-pre-hook (funcall neoscroll-pre-hook info))
      (setq neoscroll--active t neoscroll--interrupt-flag nil)
      (neoscroll--scroll-one-step move-cursor info))))

(defun neoscroll--lines-to-scroll ()
  (- neoscroll--target-line neoscroll--relative-line))

(defun neoscroll--scroll-one-step (move-cursor info)
  (let ((remaining (neoscroll--lines-to-scroll)))
    (cond
     ((or neoscroll--interrupt-flag (neoscroll--check-input) (zerop remaining))
      (when (or (bound-and-true-p hl-line-mode)
                (bound-and-true-p global-hl-line-mode))
        (run-hooks 'post-command-hook))
      (when (and (featurep 'evil) neoscroll--saved-goal-column move-cursor)
        (setq temporary-goal-column neoscroll--saved-goal-column))
      (when neoscroll-post-hook (funcall neoscroll-post-hook info))
      (setq neoscroll--timer nil neoscroll--active nil
            neoscroll--saved-goal-column nil))
     (t
      (let ((active-backup neoscroll--active))
        (setq neoscroll--active nil)
        (unwind-protect
            (if (> remaining 0)
                (progn (scroll-up 1) (forward-line 1)
                       (when (and (featurep 'evil) neoscroll--saved-goal-column)
                         (move-to-column neoscroll--saved-goal-column)))
              (progn (scroll-down 1) (forward-line -1)
                     (when (and (featurep 'evil) neoscroll--saved-goal-column)
                       (move-to-column neoscroll--saved-goal-column))))
          (setq neoscroll--active active-backup)))
      (setq neoscroll--relative-line
            (+ neoscroll--relative-line (if (> remaining 0) 1 -1)))
      (when (or (bound-and-true-p hl-line-mode)
                (bound-and-true-p global-hl-line-mode))
        (run-hooks 'post-command-hook))
      (let ((ts (/ (neoscroll--compute-time-step (abs (neoscroll--lines-to-scroll)))
                   1000.0)))
        (setq neoscroll--timer
              (run-with-timer ts nil #'neoscroll--scroll-one-step
                              move-cursor info)))))))

(defun neoscroll-ctrl-u (&optional opts)
  (interactive)
  (let ((amt (max 1 (/ (window-height) 2))))
    (neoscroll-scroll (- amt) (append opts `(:duration ,neoscroll-scroll-duration)))))

(defun neoscroll-ctrl-d (&optional opts)
  (interactive)
  (let ((amt (max 1 (/ (window-height) 2))))
    (neoscroll-scroll amt (append opts `(:duration ,neoscroll-scroll-duration)))))

(defun neoscroll-ctrl-b (&optional opts)
  (interactive)
  (neoscroll-scroll (- (window-height))
                    (append opts `(:duration ,neoscroll-page-duration))))

(defun neoscroll-ctrl-f (&optional opts)
  (interactive)
  (neoscroll-scroll (window-height)
                    (append opts `(:duration ,neoscroll-page-duration))))

(defun neoscroll-ctrl-y (&optional opts)
  (interactive)
  (neoscroll-scroll (- neoscroll-line-step)
                    (append opts `(:duration ,neoscroll-line-duration :move-cursor nil))))

(defun neoscroll-ctrl-e (&optional opts)
  (interactive)
  (neoscroll-scroll neoscroll-line-step
                    (append opts `(:duration ,neoscroll-line-duration :move-cursor nil))))

(defun neoscroll-setup (&optional config)
  "Setup neoscroll with CONFIG options."
  (when config
    (cl-loop for (key . value) in config do
             (set (intern (concat "neoscroll-" (symbol-name key))) value)))
  (when (and (display-graphic-p)
             (fboundp 'pixel-scroll-precision-mode))
    (pixel-scroll-precision-mode 1)))

(defun neoscroll--setup-evil-integration ()
  (when (featurep 'evil)
    (advice-add 'evil-next-line :before #'neoscroll--interrupt)
    (advice-add 'evil-previous-line :before #'neoscroll--interrupt)
    (advice-add 'evil-forward-char :before #'neoscroll--interrupt)
    (advice-add 'evil-backward-char :before #'neoscroll--interrupt)
    (when (fboundp 'evil-define-key*)
      (advice-add 'evil-scroll-down :override #'neoscroll-ctrl-d)
      (advice-add 'evil-scroll-up :override #'neoscroll-ctrl-u)
      (advice-add 'evil-scroll-page-down :override #'neoscroll-ctrl-f)
      (advice-add 'evil-scroll-page-up :override #'neoscroll-ctrl-b)
      (advice-add 'evil-scroll-line-up :override #'neoscroll-ctrl-y)
      (advice-add 'evil-scroll-line-down :override #'neoscroll-ctrl-e))))

(defun neoscroll--remove-evil-integration ()
  (when (featurep 'evil)
    (advice-remove 'evil-next-line #'neoscroll--interrupt)
    (advice-remove 'evil-previous-line #'neoscroll--interrupt)
    (advice-remove 'evil-forward-char #'neoscroll--interrupt)
    (advice-remove 'evil-backward-char #'neoscroll--interrupt)
    (advice-remove 'evil-scroll-down #'neoscroll-ctrl-d)
    (advice-remove 'evil-scroll-up #'neoscroll-ctrl-u)
    (advice-remove 'evil-scroll-page-down #'neoscroll-ctrl-f)
    (advice-remove 'evil-scroll-page-up #'neoscroll-ctrl-b)
    (advice-remove 'evil-scroll-line-up #'neoscroll-ctrl-y)
    (advice-remove 'evil-scroll-line-down #'neoscroll-ctrl-e)))

;;;###autoload
(define-minor-mode neoscroll-mode
  "Smooth scrolling minor mode."
  :global t :group 'neoscroll :lighter " Neo"
  (if neoscroll-mode
      (progn (neoscroll-setup) (neoscroll--setup-evil-integration))
    (progn (neoscroll--interrupt) (neoscroll--remove-evil-integration))))

;; ═════════════════════════════════════════════════════════════════════════════
;;  Configuration — applied when the mode is enabled
;; ═════════════════════════════════════════════════════════════════════════════

(setq neoscroll-easing 'quadratic)
(setq neoscroll-scroll-duration 0.15)
(setq neoscroll-page-duration 0.25)
(setq neoscroll-line-duration 0.025)
(setq neoscroll-line-step 1)
(setq neoscroll-stop-eof t)
(setq neoscroll-hide-cursor t)

;; Enable neoscroll globally
(neoscroll-mode 1)

;; ═════════════════════════════════════════════════════════════════════════════
;;  Statuscolumn integration — rebuild labels after animated scroll
;; ═════════════════════════════════════════════════════════════════════════════

;; Rebuild statuscolumn after each neoscroll animation step.
(advice-add 'neoscroll--scroll-one-step :after
            (lambda (&rest _) (with-demoted-errors (sc--init))))

(provide 'neoscroll)
;; neoscroll.el ends here
