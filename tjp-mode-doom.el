;;; tjp-mode-doom.el --- Doom Emacs configuration for tjp-mode -*- lexical-binding: t; -*-

;;; Commentary:
;; Doom Emacs specific configuration for TaskJuggler mode.
;; This file contains keybindings, integrations, and settings
;; specific to Doom Emacs.
;;
;; Load it from ~/.config/doom/config.el with:
;;
;;   (load! "lisp/tjp-mode-doom")

;;; Code:

;; ============================================================================
;; LOAD TJP-MODE
;; ============================================================================

(use-package! tjp-mode
  ;; Adjust if tjp-mode.el lives somewhere else, or drop this line entirely
  ;; when the package is declared in packages.el.
  :load-path "~/.config/doom/lisp"
  :mode (("\\.tjp\\'" . tjp-mode)
         ("\\.tji\\'" . tjp-mode))
  :init
  ;; Basic configuration.  Set these to absolute paths if a GUI Emacs cannot
  ;; find the TaskJuggler tools on its PATH.
  (setq tjp-man-command "tj3man")
  (setq tjp-compiler-command "tj3")
  (setq tjp-indent-offset 2)
  ;; (setq tjp-auto-validate t)  ; Enable to validate on save

  :config
  ;; tjp-mode turns eldoc on itself; company is what Doom expects to drive
  ;; completion, so that is the only hook needed here.
  (add-hook 'tjp-mode-hook 'company-mode))

;; ============================================================================
;; COMPANY BACKEND
;; ============================================================================

(after! company
  (set-company-backend! 'tjp-mode
    '(company-capf company-yasnippet company-dabbrev-code)))

;; ============================================================================
;; LOCALLEADER BINDINGS (SPC m)
;; ============================================================================

(map! :after tjp-mode
      :map tjp-mode-map
      :localleader

      ;; Compilation (c)
      (:prefix ("c" . "compile")
       "c" #'tjp-compile
       "v" #'tjp-compile-and-view
       "k" #'tjp-validate-buffer)

      ;; Navigation (g)
      (:prefix ("g" . "goto")
       "n" #'tjp-next-block
       "p" #'tjp-previous-block
       "d" #'xref-find-definitions
       "b" #'tjp-xref-go-back
       "i" #'tjp-find-include-at-point
       "m" #'imenu)

      ;; Folding (f)
      (:prefix ("f" . "fold")
       "f" #'tjp-toggle-fold
       "a" #'tjp-fold-all
       "u" #'tjp-unfold-all
       "m" #'hs-minor-mode)

      ;; Insert (i)
      (:prefix ("i" . "insert")
       "t" #'tjp-insert-task
       "r" #'tjp-insert-resource
       "R" #'tjp-insert-report
       "d" #'tjp-insert-date-prompt
       "D" #'tjp-insert-datetime)

      ;; Structure & Analysis (s)
      (:prefix ("s" . "structure")
       "s" #'tjp-show-structure
       "d" #'tjp-show-dependencies
       "a" #'tjp-show-resource-allocation
       "=" #'tjp-show-statistics)

      ;; Macro (M)
      (:prefix ("M" . "macro")
       "e" #'tjp-expand-macro-at-point
       "d" #'tjp-find-macro-definition)

      ;; Help (h)
      (:prefix ("h" . "help")
       "h" #'tjp-show-help
       "k" #'describe-mode)

      ;; Tags (t)
      (:prefix ("t" . "tags")
       "g" #'tjp-generate-tags
       "v" #'visit-tags-table))

;; ============================================================================
;; STANDARD KEYBINDINGS
;; ============================================================================

(map! :after tjp-mode
      :map tjp-mode-map
      "M-."     #'xref-find-definitions
      ;; xref-pop-marker-stack is obsolete since Emacs 29.1; tjp-xref-go-back
      ;; resolves to whichever command this Emacs provides.
      "M-,"     #'tjp-xref-go-back
      "C-c C-c" #'tjp-compile
      "C-c C-v" #'tjp-compile-and-view)

;; ============================================================================
;; EVIL MODE BINDINGS
;; ============================================================================

(map! :after tjp-mode
      :map tjp-mode-map
      :n "g d"   #'xref-find-definitions
      :n "g D"   #'xref-find-references
      :n "K"     #'tjp-show-help
      :n "] ]"   #'tjp-next-block
      :n "[ ["   #'tjp-previous-block
      :n "z a"   #'tjp-toggle-fold
      :n "z m"   #'tjp-fold-all
      :n "z r"   #'tjp-unfold-all
      :v "g d"   #'xref-find-definitions)

;; ============================================================================
;; WHICH-KEY LABELS
;; ============================================================================

(after! which-key
  (which-key-add-key-based-replacements
    "SPC m c" "compile"
    "SPC m g" "goto"
    "SPC m f" "fold"
    "SPC m i" "insert"
    "SPC m s" "structure"
    "SPC m M" "macro"
    "SPC m h" "help"
    "SPC m t" "tags"))

;; ============================================================================
;; PROJECTILE INTEGRATION
;; ============================================================================

(after! projectile
  (add-to-list 'projectile-project-root-files "project.tjp"))

;; ============================================================================
;; FILE TEMPLATES
;; ============================================================================

;; Doom does not enable auto-insert; add this to config.el to use the
;; template below:
;;
;;   (add-hook 'doom-first-file-hook #'auto-insert-mode)
(after! autoinsert
  (define-auto-insert
    '("\\.tjp\\'" . "TaskJuggler Project Template")
    '("Project ID: "
      "project " str " \"" (read-string "Project title: ") "\" "
      (format-time-string "%Y-%m-%d") " - "
      (format-time-string "%Y-%m-%d" (time-add (current-time) (days-to-time 365))) " {\n"
      "  timezone \"UTC\"\n"
      "  timeformat \"%Y-%m-%d\"\n"
      "  currency \"USD\"\n"
      "}\n"
      "\n"
      "# Resources\n"
      "resource me \"" (user-full-name) "\"\n"
      "\n"
      "# Tasks\n"
      "task start \"Get started\" {\n"
      "  effort 1d\n"
      "  allocate me\n"
      "}\n"
      "\n"
      "# Reports\n"
      ;; The quoted name - not the ID - is the base name of the generated
      ;; file, so this report is written to "Project Overview.html".
      "taskreport overview \"Project Overview\" {\n"
      "  formats html\n"
      "  columns name, start, end, effort, chart\n"
      "  loadunit days\n"
      "  hideresource 1\n"
      "}\n")))

;; ============================================================================
;; PERFORMANCE OPTIMIZATION
;; ============================================================================

(add-hook 'tjp-mode-hook
          (lambda ()
            (when (> (buffer-size) 1000000)
              (message "Large TaskJuggler file detected, disabling some features...")
              ;; Rescanning the project for completion is the expensive part
              ;; in a file this size; let a scan live longer.
              (setq-local tjp-cache-ttl 30)
              (when (bound-and-true-p flycheck-mode)
                (flycheck-mode -1))
              (when (bound-and-true-p hs-minor-mode)
                (hs-minor-mode -1)))))

(provide 'tjp-mode-doom)
;;; tjp-mode-doom.el ends here
