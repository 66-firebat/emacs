;; -*- lexical-binding: t; -*-
;;
;; =============================================================================
;;  orderless.el — Orderless Completion Style
;;
;;  Orderless is a completion style that splits the input into space-separated
;;  components and matches each component independently against the candidates.
;;  This enables flexible "best match" filtering — e.g., "fo ba" matches
;;  "foobar", "foo bar", etc.
;;
;;  Configuration:
;;    completion-styles:          Uses 'orderless as the primary style, with
;;                                'basic as a fallback for partial input.
;;    completion-category-overrides: File completions use 'orderless + 'basic.
;; =============================================================================

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles orderless basic)))))

(provide 'orderless)
;; orderless.el ends here
