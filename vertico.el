;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  vertico.el — Vertico configuration
;;
;;  Candidate count with brackets: "[1/2]" instead of "1/2 ".
;; =============================================================================

(with-eval-after-load 'vertico
  (setq vertico-count-format '("%s " . "[%s/%s]")))
