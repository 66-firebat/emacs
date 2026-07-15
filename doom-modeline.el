;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  doom-modeline.el — Doom Modeline Customization
;;
;;  A clean, informative mode line with Nerd Font icons.
;;  Shows the absolute line number before the buffer name.
;; =============================================================================

;; ── Modeline setup ───────────────────────────────────────

;; Nerd Icons font — required by doom-modeline for mode line icons
(use-package nerd-icons
  :commands nerd-icons-install-fonts
  :config
  (setq nerd-icons-font-family "Symbols Nerd Font Mono"))

(use-package doom-modeline
  :demand t
  :config
  (doom-modeline-mode 1)

  ;; Face for the git branch/hash segment (fallback default;
  ;; overridden by the firebat theme via custom-theme-set-faces)
  (defface doom-modeline-git-branch
    '((t (:background "#ff4400" :foreground "#2b2b2b")))
    "Face for the git branch:hash segment in the modeline."
    :group 'doom-modeline-faces)

  ;; Evil state faces — custom colors
  (custom-set-faces
    '(doom-modeline-evil-normal-state ((t (:foreground "#ff4400" :background nil))))
    '(doom-modeline-evil-insert-state ((t (:foreground "#838383" :background nil))))
    '(doom-modeline-evil-visual-state  ((t (:foreground "#1bfd9c" :background nil)))))

  ;; Helper: git diff stats string
  (defun my/gitsigns-str ()
    "Return git diff stats:  N  C  K, or 󰦕 for non-VC buffers.
Hunks with both + and - are counted as changes ()."
    ;; Only show in file-visiting buffers (not dired, eat, etc.)
    (if (not buffer-file-name) nil
      (if (not (ignore-errors (vc-backend buffer-file-name)))
          "󰦕 "
      (condition-case nil
          (let* ((file buffer-file-name)
                 (default-directory (file-name-directory file))
                 (inserts 0) (changes 0) (deletes 0))
            (with-temp-buffer
              (call-process "git" nil t nil "diff" "--" file)
              (goto-char (point-min))
              ;; Walk through each hunk
              (while (re-search-forward "^@@ " nil t)
                (forward-line)
                (let ((hunk-inserts 0) (hunk-deletes 0))
                  (while (and (not (eobp))
                              (not (looking-at "^@@")))
                    (cond ((looking-at "^\\+") (cl-incf hunk-inserts))
                          ((looking-at "^-")   (cl-incf hunk-deletes)))
                    (forward-line))
                  ;; Match diff-hl: in a mixed hunk, each + line = 1 change.
                  ;; Pure hunks count individual lines.
                  (if (and (> hunk-inserts 0) (> hunk-deletes 0))
                      (cl-incf changes hunk-inserts)
                    (progn
                      (cl-incf inserts hunk-inserts)
                      (cl-incf deletes hunk-deletes))))))
            (if (> (+ inserts changes deletes) 0)
                (string-join
                 (delq nil
                       (list
                        (when (> inserts 0) (format "+ %d" inserts))
                        (when (> changes 0) (format "≠ %d" changes))
                        (when (> deletes 0) (format "✕ %d" deletes))))
                 " ")
              "󰦕 "))
        (error "󰦕 ")))))

  ;; Truncation variable for branch name
  (defvar my/doom-modeline-git-branch-truncate nil
    "Maximum length for git branch name in the modeline.
If nil, the full branch name is displayed without truncation.
Set to a number (e.g., 20) to truncate branch names to that
many characters, appending a trailing ellipsis if needed.")

  ;; Helper: git branch info
  (defun my/get-git-branch-info ()
    "Return \"<branch name>: <short_hash>\" or \"---\" if not in a git repo.
Truncates the branch name according to
`my/doom-modeline-git-branch-truncate'."
    (if (or (not buffer-file-name)
            (not (ignore-errors (vc-backend buffer-file-name))))
        "---"
      (condition-case nil
          (let* ((default-directory (file-name-directory buffer-file-name))
                 (branch (with-temp-buffer
                           (call-process "git" nil t nil "rev-parse" "--abbrev-ref" "HEAD")
                           (string-trim (buffer-string))))
                 (hash (with-temp-buffer
                         (call-process "git" nil t nil "rev-parse" "--short" "HEAD")
                         (string-trim (buffer-string)))
                       ))
            ;; Apply truncation if configured
            (when (and my/doom-modeline-git-branch-truncate
                       (> (length branch) my/doom-modeline-git-branch-truncate))
              (setq branch (concat (substring branch 0 my/doom-modeline-git-branch-truncate) "…")))
            (format "%s  %s" branch hash))
        (error "---"))))

  ;; Git diff stats segment
  (doom-modeline-def-segment my-gitsigns
    "Git diff stats:  N  C  K"
    (let ((str (my/gitsigns-str)))
      (when str
        (concat (doom-modeline-spc) str))))

  ;; Git branch & hash segment
  (doom-modeline-def-segment my-git-branch
    "Git branch name and short commit hash: <branch>: <hash>"
    (let ((info (my/get-git-branch-info)))
      (concat (propertize "  "
                          'face '(:foreground "#ff4400" :background "#2b2b2b"))
              (propertize (concat (doom-modeline-spc) info " ")
                          'face 'doom-modeline-git-branch)
              (propertize ""
                          'face '(:foreground "#ff4400" :background "#2b2b2b")))))

  ;; Terminal-friendly tweaks
  (setq doom-modeline-height 1)
  (setq doom-modeline-bar-width 1)
  (setq doom-modeline-major-mode-icon t)
  (setq doom-modeline-minor-modes nil)
  (setq doom-modeline-enable-word-count nil)
  (setq doom-modeline-buffer-encoding nil)
  (setq doom-modeline-indent-info nil)
  (setq doom-modeline-env-version t)
  (setq doom-modeline-github nil)
  ;; Custom buffer-info: buffer name followed by state icon.
  ;; Mode icon (/) removed — you already know what mode you're in.
  (doom-modeline-def-segment my-buffer-info
    "Buffer name with state icon after the name, no mode icon."
    (concat
     (doom-modeline-spc)
     (doom-modeline--buffer-name)
     " "
     (doom-modeline--buffer-state-icon)))

  ;; Custom evil segment with a leading space before the icon.
  (doom-modeline-def-segment my-evil
    "Evil state with a leading space."
    (when doom-modeline-modal
      (let ((evil (doom-modeline--evil)))
        (when evil (concat (doom-modeline-spc) (doom-modeline-spc) evil)))))

  ;; Redefine the main modeline.
  (doom-modeline-def-modeline 'main
    '(eldoc bar window-state workspace-name window-number
            my-evil matches follow my-git-branch my-gitsigns my-buffer-info remote-host)
    '(compilation objed-state misc-info project-name persp-name
                  battery grip irc mu4e gnus github debug repl
                  minor-modes input-method indent-info buffer-encoding
                  process check time))
  ;; Apply the redefined modeline
  (doom-modeline-set-modeline 'main t))

(provide 'doom-modeline)
;; doom-modeline.el ends here
