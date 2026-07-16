# PATCH 1-0-5 — Smart window navigation with `Alt + w` / `Alt + Shift + w`

## Goal

| Binding | Frame state | Behavior |
|---------|-------------|----------|
| `Alt + w` | 1 window | Split right, switch to the new window |
| `Alt + w` | 2+ windows | Cycle to the next window (same as `C-w w`) |
| `Alt + Shift + w` | 2+ windows | Close the current window (`delete-window`) |
| `Alt + Shift + w` | 1 window (last) | Echo "Last window in frame, doing nothing" |

## Proposed implementation

### 1. Functions (in `keybinds.el`)

```elisp
(defun my/smart-other-window ()
  "Switch to the other window.  If only one window exists, split right first."
  (interactive)
  (if (= (length (window-list)) 1)
      (progn
        (split-window-right)
        (other-window 1))
    (other-window 1)))

(defun my/smart-close-window ()
  "Close the current window.  If it's the last window in the frame, do nothing."
  (interactive)
  (if (= (length (window-list)) 1)
      (message "Last window in frame, doing nothing")
    (delete-window)))
```

### 2. Keybindings (in `keybinds.el`)

Added to the existing override keymap block:

```elisp
;; ── Global Master Keybinds ────────────────────────────────────────
;; Bound in the override keymap so it takes precedence over ALL
;; mode-specific bindings ...
(general-def :keymaps 'override
  "M-t" 'my/eat-new
  "M-r" 'consult-recent-file
  "M-k" 'kill-current-buffer
  "M-z" 'my/zoxide-travel-dispatch
  "M-w"  'my/smart-other-window     ;; ← added
  "M-W"  'my/smart-close-window)    ;; ← added
```

### 3. Eat non-bound keys (in `keybinds.el`)

Because these bindings use the `Alt` modifier, they must be added to eat's `eat-semi-char-non-bound-keys` list — otherwise eat will intercept them in semi-char mode and send them to the terminal instead of letting Emacs handle them. The key format is `[?\e ?<char>]` for `Alt + <char>` and `[?\e ?<C>]` for `Alt + Shift + <char>`.

Add both to the `dolist`:

```elisp
(with-eval-after-load 'eat
  (dolist (key '(...
                 ("M-w" . [?\e ?w])
                 ("M-W" . [?\e ?W])))
    ...))
```

### 4. Hyprland check

Verify neither `Alt + w` nor `Alt + Shift + w` is bound in `keymaps.lua`.

---

## Edge cases

| Scenario | Behavior |
|----------|----------|
| `Alt + w`, 1 window | Splits right, new window focused |
| `Alt + w`, 2+ windows | Cycles like `C-w w` |
| `Alt + Shift + w`, 2+ windows | Closes current window |
| `Alt + Shift + w`, 1 window | Messages "Last window in frame, doing nothing" |
| In eat terminal | Both work via eat non-bound keys |
