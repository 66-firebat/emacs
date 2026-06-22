;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  vterm.el — Terminal Emulator Configuration
;;
;;  Built on the emacs-libvterm package (installed via NixOS).
;;  Requires: (emacsPackages.vterm) in configuration.nix
;;
;;  Design choices:
;;    - Normal-by-default: vterm starts in evil NORMAL state
;;    - `i` enters insert state; ESC returns to normal state
;;    - Shell integration enabled for directory tracking
;; =============================================================================

;; ── Load autoloads ─────────────────────────────────────────────
;; vterm is installed via NixOS, not MELPA, so package-initialize
;; doesn't register its autoloads. Load them explicitly so
;; M-x vterm (and SPC t t) appear as available commands.
(require 'vterm-autoloads)

;; ── Terminal width: account for statuscolumn ───────────────────
;; vterm calculates terminal width as
;;   (window-max-chars-per-line) - (vterm--get-margin-width)
;; vterm--get-margin-width only accounts for display-line-numbers-mode.
;; The statuscolumn adds ~9 chars of before-string ("     1 ┃ ") on
;; every line, which also reduces the visible text area.
;;
;; We add the advice at top level (no with-eval-after-load) so it
;; activates BEFORE vterm initialises its terminal width.
(defun my/vterm--statuscolumn-width ()
  (+ (if (fboundp 'sc--num-width) (sc--num-width) 5) 4))

(advice-add 'vterm--get-margin-width :filter-return
            (lambda (width)
              (+ width (my/vterm--statuscolumn-width))))

;; After vterm-mode activates, force a terminal resize so the
;; advised margin width takes effect immediately.
(add-hook 'vterm-mode-hook
          (lambda ()
            (when (and (bound-and-true-p vterm--process)
                       (process-live-p vterm--process))
              (vterm--window-adjust-process-window-size
               vterm--process (window-list)))))

;; ── Initial state: normal-by-default ────────────────────────────
;; New vterms start in normal state. Press `i` to enter insert mode.
(evil-set-initial-state 'vterm-mode 'normal)

;; ── Evil keybindings ───────────────────────────────────────────
;; All handled by evil-collection — uses insert state so
;; i/a/A/I enter insert mode, ESC returns to normal state.
;; See evil-collection-vterm.el in the elpa directory.

;; ── Unbind C-b in vterm insert state ──────────────────────
;; evil-collection binds C-b to vterm--self-insert (pass to
;; terminal). We unbind it so C-b can reach the global
;; consult-buffer binding instead.
(add-hook 'vterm-mode-hook
          (lambda ()
            (evil-define-key* 'insert vterm-mode-map (kbd "C-b") nil)))

;; ── Auto-insert helper ──────────────────────────────────────────
;; Used via :after advice on specific buffer-switching commands.
;; Currently advised on: my/switch-to-other-buffer (SPC b r).
(defun my/vterm-enter-insert-after-switch (&rest _)
  "After switching to a vterm buffer, enter insert state."
  (when (and (derived-mode-p 'vterm-mode)
             (not (minibufferp))
             (not (evil-insert-state-p)))
    (evil-insert-state)))

;; ── Cursor snap ──────────────────────────────────────────────
;; After entering insert mode (i/I), send an ANSI "Report Cursor
;; Position" escape sequence (\e[6n) to the terminal. This forces
;; the terminal to respond, which triggers the vterm module to
;; re-evaluate its display, snapping the visual cursor to the
;; correct position immediately.
(defun my/vterm-snap-cursor (&rest _)
  "Snap the visual cursor by sending SPACE + BACKSPACE to the shell.
The shell echoes the space then deletes it with backspace, so
there is no visible effect. But the actual I/O forces the vterm
module to update the cursor display immediately, which is more
reliable than sending an ANSI escape that waits for the event loop.

Note: This may have side effects if a full-screen program (like
less, vim, htop) is active inside vterm when i/I is pressed,
since the space+backspace would be consumed by that program."
  (when (and (derived-mode-p 'vterm-mode)
             (bound-and-true-p vterm--process))
    (process-send-string vterm--process " \x7f")))

(with-eval-after-load 'evil-collection-vterm
  (advice-add 'evil-collection-vterm-insert :after #'my/vterm-snap-cursor)
  (advice-add 'evil-collection-vterm-insert-line :after #'my/vterm-snap-cursor))

;; ── Shell integration ──────────────────────────────────────────
;; Directory tracking: Emacs knows the shell's current directory.
;; The shell-side script is sourced in .bashrc:
;;
;;   if [[ "$INSIDE_EMACS" == "vterm" ]]; then
;;       source "${EMACS_VTERM_PATH%%\/libexec\/vterm*}/etc/emacs-vterm-bash.sh"
;;   fi

(provide 'vterm)
;; vterm.el ends here
