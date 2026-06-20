;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  pi.el — Pi Coding Agent (pi-coding-agent) Integration
;;
;;  Provides an Emacs frontend for the Pi Coding Agent (https://pi.dev).
;;  Pi CLI runs the agent, talks to models, and executes tools. This package
;;  wraps Pi in an ergonomic Emacs interface: a Markdown chat buffer for the
;;  conversation and a separate prompt buffer where you compose messages.
;;
;;  Requirements:
;;    - Emacs 29.1+ with tree-sitter support
;;    - Pi CLI (@earendil-works/pi-coding-agent) installed and in PATH
;;    - Authentication: pi --login, or provider API keys configured for pi
;;
;;  Quick start:
;;    M-x pi-coding-agent        Start or focus session in current project
;;    C-u M-x pi-coding-agent    Start a named (multi) session
;;    M-x pi-coding-agent-toggle Hide/show session windows
;;    M-x pi                     Alias for pi-coding-agent (defalias below)
;;
;;  Key Bindings (input buffer):
;;    C-c C-c  Send prompt (queues follow-up if busy)
;;    C-c C-s  Queue steering message (interrupts after current tool)
;;    C-c C-k  Abort streaming
;;    C-c C-p  Open transient menu (model, thinking, sessions, commands)
;;    C-c C-r  Resume a previous session
;;    M-p/M-n  Prompt history
;;    TAB      Complete paths and slash commands (/)
;;
;;  Key Bindings (chat buffer):
;;    n / p    Navigate user messages
;;    TAB      Toggle tool output / thinking block / turn
;;    RET      Visit file at point (from tool blocks)
;;    f        Fork conversation from turn at point
;;    q        Quit session
;; =============================================================================

;; ---------------------------------------------------------------------------
;;  Package Installation & Basic Configuration
;; ---------------------------------------------------------------------------

(use-package pi-coding-agent
  :ensure t
  :defer t
  :custom
  ;; If `pi` is not in your PATH (e.g. you use npx or mise), uncomment
  ;; one of the alternatives below:
  ;;
  ;; npx users:
  ;; (pi-coding-agent-executable '("npx" "-y" "@earendil-works/pi-coding-agent@latest"))
  ;;
  ;; mise users:
  ;; (pi-coding-agent-executable '("mise" "x" "npm:@earendil-works/pi-coding-agent@latest" "--" "pi"))
  ;;
  ;; Default: pi is expected to be on PATH
  (pi-coding-agent-executable '("pi"))

  ;; How many seconds to wait for synchronous RPC calls
  (pi-coding-agent-rpc-timeout 30)

  ;; Height of the input window (the bottom prompt buffer) in lines
  (pi-coding-agent-input-window-height 10)

  ;; Width of section separators (horizontal rules in chat)
  (pi-coding-agent-separator-width 72)

  ;; Tool output preview: max visual lines before collapsing
  (pi-coding-agent-tool-preview-lines 10)

  ;; Bash output is typically more verbose — show fewer preview lines
  (pi-coding-agent-bash-preview-lines 5)

  ;; Max bytes for tool output preview (50KB default)
  (pi-coding-agent-preview-max-bytes 51200)

  ;; Context usage percentage thresholds for header-line colour
  (pi-coding-agent-context-warning-threshold 70)
  (pi-coding-agent-context-error-threshold 90)

  ;; Visit files from tool blocks in the other window (chat stays visible)
  (pi-coding-agent-visit-file-other-window t)

  ;; Enable Markdown syntax highlighting in the input buffer (bold, italic,
  ;; code spans, fenced code blocks via tree-sitter)
  (pi-coding-agent-input-markdown-highlighting t)

  ;; Copy raw markdown from chat buffer (preserve **bold**, backticks, etc.)
  (pi-coding-agent-copy-raw-markdown nil)

  ;; How many recent headed chat turns stay "hot" for table redisplay
  (pi-coding-agent-hot-tail-turn-count 3)

  ;; Prettify Markdown pipe tables with Unicode box-drawing characters
  (pi-coding-agent-prettify-tables t)

  ;; Project trust policy for .pi resources (prompts, skills, settings, etc.)
  ;;   'approve    — (default) pass --approve, trust project-local Pi resources
  ;;   'default    — let Pi use its saved trust decisions from trust.json
  ;;   'no-approve — pass --no-approve, ignore project-local Pi files
  ;;
  ;; NOTE: Using 'default here because the installed Pi CLI (v1.0.0) does
  ;; not support --approve. Upgrade with: npm update -g @earendil-works/pi-coding-agent
  (pi-coding-agent-project-trust-policy 'default)

  :config
  ;; Register activity phase hooks — useful for notifications or mode-line
  ;; updates. Each function receives 5 args:
  ;;   CHAT-BUFFER INPUT-BUFFER OLD-PHASE NEW-PHASE REASON
  ;; NEW-PHASE: "thinking", "replying", "running", "compact", "idle"
  ;; REASON:    'phase-change, 'reset, 'teardown, 'input-link, 'input-unlink
  (add-hook 'pi-coding-agent-activity-phase-functions
            (defun my/pi-activity-phase-notify (_chat-buf _input-buf _old new-phase _reason)
              "Echo phase transitions to the minibuffer."
              (pcase new-phase
                ("thinking" (message "pi is thinking…"))
                ("replying" (message "pi is replying…"))
                ("running"  (message "pi is running tools…"))
                ("idle"     nil)
                (_          nil)))))

;; ---------------------------------------------------------------------------
;;  Convenience alias
;; ---------------------------------------------------------------------------

;; `M-x pi` starts or focuses the current project's pi session — shorter
;; than typing `M-x pi-coding-agent` every time.
(defalias 'pi 'pi-coding-agent)



;; ---------------------------------------------------------------------------
;;  Custom Commands via Slash Command Runner (Pi 0.79+)
;; ---------------------------------------------------------------------------

;; Example: define an Emacs command that runs a Pi slash command by name.
;; Uncomment and adapt to your own slash commands:
;;
;; (defun my/pi-review ()
;;   "Run the pi 'review' slash command in the current session."
;;   (interactive)
;;   (pi-coding-agent-run-command "review"))

;; ---------------------------------------------------------------------------
;;  Extension Status Faces (Pi 0.79+ / pi-coding-agent 2.5.0+)
;; ---------------------------------------------------------------------------

;; Style individual extension header statuses by their statusKey.
;; Uncomment and customise for your extensions:
;;
;; (setopt pi-coding-agent-extension-status-faces
;;   '(("ok"   . success)
;;     ("warn" . warning)
;;     ("err"  . error)
;;     ("info" . font-lock-doc-face)))

(provide 'pi)
;; pi.el ends here
