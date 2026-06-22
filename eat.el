;; -*- lexical-binding: t; -*-

(use-package eat
  :ensure t
  :config
  (setq eat-enable-shell-integration t)
  (setq eat-default-input-mode 'semi-char))

(provide 'eat)
