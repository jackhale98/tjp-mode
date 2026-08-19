;;; tjp-evil.el --- Evil and localleader bindings for tjp-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2025 TaskJuggler Developers

;; Author: TaskJuggler Developers <taskjuggler-devel@googlegroups.com>
;; Keywords: languages, project management
;; Version: 2.2.0
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/jackhale98/tjp-mode

;; This file is part of tjp-mode.

;;; Commentary:

;; Optional evil-mode keybindings for `tjp-mode'.
;;
;; Provides two layers of bindings, both generated from the single table
;; in `tjp-evil-localleader-bindings':
;;
;;   1. `SPC m' major-mode leader via general.el - Doom and Spacemacs
;;      style, activated only when general.el is loaded.
;;   2. `,' localleader fallback via `evil-define-key*' - works for
;;      every evil user without extra packages.
;;
;; Plus the usual normal-state motions: `gd', `K', `]]', `[[', `za',
;; `zm', `zr'.
;;
;; Neither evil nor general is a hard dependency; both are loaded lazily
;; through `with-eval-after-load', so requiring this file from a vanilla
;; Emacs does nothing at all.  `tjp-mode' requires it automatically when
;; it is on the load path, so installing the package from git is enough
;; - there is nothing to copy into your configuration.

;;; Code:

;; Forward declarations for optional dependencies
(declare-function evil-define-key* "evil-core")
(declare-function general-define-key "general")

(declare-function tjp-compile "tjp-mode")
(declare-function tjp-compile-and-view "tjp-mode")
(declare-function tjp-validate-buffer "tjp-mode")
(declare-function tjp-next-block "tjp-mode")
(declare-function tjp-previous-block "tjp-mode")
(declare-function tjp-find-include-at-point "tjp-mode")
(declare-function tjp-xref-go-back "tjp-mode")
(declare-function tjp-toggle-fold "tjp-mode")
(declare-function tjp-fold-all "tjp-mode")
(declare-function tjp-unfold-all "tjp-mode")
(declare-function tjp-insert-task "tjp-mode")
(declare-function tjp-insert-resource "tjp-mode")
(declare-function tjp-insert-report "tjp-mode")
(declare-function tjp-insert-date-prompt "tjp-mode")
(declare-function tjp-insert-datetime "tjp-mode")
(declare-function tjp-show-structure "tjp-mode")
(declare-function tjp-show-dependencies "tjp-mode")
(declare-function tjp-show-resource-allocation "tjp-mode")
(declare-function tjp-show-statistics "tjp-mode")
(declare-function tjp-expand-macro-at-point "tjp-mode")
(declare-function tjp-find-macro-definition "tjp-mode")
(declare-function tjp-show-help "tjp-mode")
(declare-function tjp-generate-tags "tjp-mode")

(defvar tjp-mode-map)

;; ============================================================================
;; BINDING TABLE
;; ============================================================================

(defconst tjp-evil-localleader-bindings
  '(("c"   :group "compile")
    ("c c" tjp-compile                "compile")
    ("c v" tjp-compile-and-view       "compile & view report")
    ("c k" tjp-validate-buffer        "check syntax")

    ("g"   :group "goto")
    ("g n" tjp-next-block             "next block")
    ("g p" tjp-previous-block         "previous block")
    ("g d" xref-find-definitions      "definition")
    ("g b" tjp-xref-go-back           "back")
    ("g i" tjp-find-include-at-point  "include file")
    ("g m" imenu                      "imenu")

    ("f"   :group "fold")
    ("f f" tjp-toggle-fold            "toggle")
    ("f a" tjp-fold-all               "fold all")
    ("f u" tjp-unfold-all             "unfold all")
    ("f m" hs-minor-mode              "hideshow mode")

    ("i"   :group "insert")
    ("i t" tjp-insert-task            "task")
    ("i r" tjp-insert-resource        "resource")
    ("i R" tjp-insert-report          "report")
    ("i d" tjp-insert-date-prompt     "date")
    ("i D" tjp-insert-datetime        "datetime")

    ("s"   :group "structure")
    ("s s" tjp-show-structure         "structure")
    ("s d" tjp-show-dependencies      "dependencies")
    ("s a" tjp-show-resource-allocation "resource allocation")
    ("s =" tjp-show-statistics        "statistics")

    ("M"   :group "macro")
    ("M e" tjp-expand-macro-at-point  "expand macro")
    ("M d" tjp-find-macro-definition  "macro definition")

    ("h"   :group "help")
    ("h h" tjp-show-help              "keyword help (tj3man)")
    ("h k" describe-mode              "describe mode")

    ("t"   :group "tags")
    ("t g" tjp-generate-tags          "generate TAGS")
    ("t v" visit-tags-table           "visit tags table"))
  "Localleader bindings for `tjp-mode'.
Each entry is either (KEYS :group LABEL), declaring a prefix, or
\(KEYS COMMAND LABEL).  The same table drives the general.el `SPC m'
bindings and the `,' fallback for plain evil users.")

(defun tjp-evil--general-args ()
  "Return `tjp-evil-localleader-bindings' as `general-define-key' arguments."
  (apply #'append
         (mapcar (lambda (entry)
                   (if (eq (nth 1 entry) :group)
                       (list (car entry) `(:ignore t :which-key ,(nth 2 entry)))
                     (list (car entry) `(,(nth 1 entry) :which-key ,(nth 2 entry)))))
                 tjp-evil-localleader-bindings)))

;; ============================================================================
;; EVIL BINDINGS
;; ============================================================================

(with-eval-after-load 'evil
  ;; Normal-state motions.
  (evil-define-key* 'normal tjp-mode-map
    (kbd "g d") #'xref-find-definitions
    (kbd "g D") #'xref-find-references
    (kbd "K")   #'tjp-show-help
    (kbd "] ]") #'tjp-next-block
    (kbd "[ [") #'tjp-previous-block
    (kbd "z a") #'tjp-toggle-fold
    (kbd "z m") #'tjp-fold-all
    (kbd "z r") #'tjp-unfold-all)
  (evil-define-key* 'visual tjp-mode-map
    (kbd "g d") #'xref-find-definitions)

  ;; `,' localleader for evil users without Doom or Spacemacs.
  (dolist (entry tjp-evil-localleader-bindings)
    (unless (eq (nth 1 entry) :group)
      (evil-define-key* 'normal tjp-mode-map
        (kbd (concat ", " (car entry))) (nth 1 entry))))

  ;; `SPC m' major-mode leader for Doom and Spacemacs.
  (with-eval-after-load 'general
    (apply #'general-define-key
           :states 'normal
           :keymaps 'tjp-mode-map
           :prefix "SPC m"
           (tjp-evil--general-args))))

(provide 'tjp-evil)
;;; tjp-evil.el ends here
