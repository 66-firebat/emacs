;;; grease-options.el --- Grease options -*- lexical-binding: t; -*-

;;; Commentary:
;; Option settings for the Grease file manager.
;; Loaded from init.el immediately before grease/grease.el, so
;; load-time switches (like `grease-load-plugins') take effect.

;;; Code:

(setq grease-show-hidden t)          ;; Show hidden files (dotfiles) in grease
(setq grease-load-plugins t)         ;; Load .el plugins from grease/plugins/

(provide 'grease-options)
;;; grease-options.el ends here
