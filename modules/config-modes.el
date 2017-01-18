;; -*- lexical-binding: t -*-
(require 'cl-lib)
(require 'config-package)

(eval-when-compile
  (with-demoted-errors "Load error: %s"
    (require 'evil)
    (require 'flycheck)
    (require 'config-setq)))

;; =============================================================================
;; Emacs Lisp ==================================================================
;; =============================================================================

(add-hook 'lisp-interaction-mode-hook #'auto-save-mode)

(defun emacs-lisp-goto-definition ()
  (interactive)
  (find-function (function-called-at-point)))

(defun replace-last-sexp ()
  (interactive)
  (let ((value (eval (elisp--preceding-sexp))))
    (kill-sexp -1)
    (insert (format "%S" value))))

(defun my/auto-compile-onetime-setup ()
  (require 'auto-compile)
  (auto-compile-on-save-mode +1)
  (remove-hook 'before-save-hook #'my/auto-compile-onetime-setup t))

(with-eval-after-load 'eldoc
  (diminish 'eldoc-mode)

  (defun nadvice/eldoc-display-message-no-interference-p (old-fun &rest args)
    (and (apply old-fun args)
         (not (and (my/sp-on-delimiter-p)
                   (not (minibufferp))))
         (not (and (bound-and-true-p flycheck-mode)
                   (flycheck-overlay-errors-at (point))))))

  (advice-add 'eldoc-display-message-no-interference-p :around
              #'nadvice/eldoc-display-message-no-interference-p))

(with-eval-after-load 'lisp-mode
  (with-eval-after-load 'smartparens
    (sp-local-pair 'emacs-lisp-mode "'" nil :actions nil)
    (sp-local-pair 'emacs-lisp-mode "`" nil :when '(sp-in-string-p)))

  (add-hook 'emacs-lisp-mode-hook
            (lambda ()
              (setq mode-name (if (display-graphic-p) "λ" "EL"))

              (eldoc-mode +1)
              (auto-indent-mode -1)
              (aggressive-indent-mode +1)
              (add-hook 'before-save-hook
                        #'my/auto-compile-onetime-setup nil t)))

  (define-key emacs-lisp-mode-map (kbd "C-c e") #'replace-last-sexp)
  (define-key emacs-lisp-mode-map (kbd "M-.") #'emacs-lisp-goto-definition)
  (define-key emacs-lisp-mode-map (kbd "M-,") #'evil-jump-backward)

  (evil-define-key 'normal emacs-lisp-mode-map "gd"
    #'emacs-lisp-goto-definition))

;; =============================================================================
;; C-like ======================================================================
;; =============================================================================

(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode))

(with-eval-after-load 'cc-mode
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'cc-mode)))
  (package-deferred-install 'irony
      :autoload-names '('irony-mode
                        'irony-version
                        'irony-server-kill
                        'irony-cdb-autosetup-compile-options
                        'irony-cdb-menu
                        'irony-cdb-clang-complete
                        'irony-cdb-json
                        'irony-cdb-json-add-compile-commands-path
                        'irony-cdb-libclang
                        'irony-completion-at-point
                        'irony-completion-at-point-async)
      (add-to-list 'irony-additional-clang-options "-std=c++14")
    (add-hook 'irony-mode-hook 'irony-cdb-autosetup-compile-options))

  (package-deferred-install '(irony-eldoc :repo "josteink/irony-eldoc"
                                          :fetcher github)
      :autoload-names '('irony-eldoc))

  (package-deferred-install 'company-irony
      :autoload-names '('company-irony
                        'company-irony-setup-begin-commands))

  (package-deferred-install 'flycheck-irony
      :autoload-names '('flycheck-irony-setup))

  (package-deferred-install 'clang-format
      :autoload-names '('clang-format
                        'clang-format-region
                        'clang-format-buffer))

  (with-eval-after-load 'irony
    (flycheck-irony-setup))

  (setq c-default-style "k&r")

  (cl-macrolet
      ((my/setup-cc-mode
        (mode hook)
        `(add-hook ,hook (lambda ()
                           (when (eq major-mode ,mode)
                             (irony-mode +1)
                             (eldoc-mode +1)
                             (irony-eldoc +1)
                             (semantic-idle-summary-mode -1))))))

    (with-no-warnings
      (my/generate-calls
          'my/setup-cc-mode
        '(('c++-mode  'c++-mode-hook)
          ('objc-mode 'objc-mode-hook)
          ('c-mode    'c-mode-hook)))))

  (with-eval-after-load 'smartparens
    (sp-with-modes
        '(c++-mode objc-mode c-mode)
      (sp-local-pair "/*" "*/" :post-handlers
                     '(:add
                       ("* ||\n[i]" "RET")))
      (sp-local-pair "{" nil :post-handlers
                     '(:add
                       ("||\n[i]" "RET")
                       ("| " "SPC")))))

  (package-deferred-install 'srefactor
      :autoload-names '('srefactor-refactor-at-point)
      (define-key c-mode-map (kbd "M-RET") #'srefactor-refactor-at-point)
    (define-key c++-mode-map (kbd "M-RET") #'srefactor-refactor-at-point)))

(package-deferred-install 'arduino-mode
    :mode-entries '('("\\.pde\\'" . arduino-mode)
                    '("\\.ino\\'" . arduino-mode))
    :autoload-names '('arduino-mode)
    (package-deferred-install 'company-arduino
        :autoload-names '('company-arduino-append-include-dirs
                          'company-arduino-sketch-directory-p
                          'company-arduino-turn-on
                          'company-arduino-turn-off))
    (add-hook 'irony-mode-hook 'company-arduino-turn-on))

(package-deferred-install 'cuda-mode
    :mode-entries '('("\\.cu\\'" . cuda-mode)
                    '("\\.cuh\\'" . cuda-mode))
    :autoload-names '('cuda-mode))

(package-deferred-install 'glsl-mode
    :mode-entries '('("\\.vert\\'" . glsl-mode)
                    '("\\.frag\\'" . glsl-mode)
                    '("\\.geom\\'" . glsl-mode)
                    '("\\.glsl\\'" . glsl-mode))
    :autoload-names '('glsl-mode))

(package-deferred-install '(asy-mode :repo "vectorgraphics/asymptote"
                                     :fetcher github
                                     :files "base/*.el")
    :feature-name 'asy-mode
    :mode-entries '('("\\.asy$" . asy-mode))
    :autoload-names '('asy-mode))

;; =============================================================================
;; Javascript ==================================================================
;; =============================================================================

(package-deferred-install 'js2-mode
    :autoload-names '('js2-minor-mode
                      'js2-mode
                      'js2-highlight-unused-variables-mode
                      'js2-imenu-extras-mode
                      'js2-imenu-extras-setup
                      'js2-jsx-mode)

    (package-deferred-install 'js2-refactor
        :autoload-names '('js2r-add-keybindings-with-prefix
                          'js2r-add-keybindings-with-modifier
                          'js2r-extract-var
                          'js2-refactor-mode))

    (set-face-foreground 'js2-external-variable
                         (face-foreground 'default))

    (set-face-attribute 'js2-external-variable nil :weight 'extra-bold)
    (set-face-attribute 'js2-external-variable nil :underline t)
    (js2r-add-keybindings-with-prefix "C-c C-r")

    (with-eval-after-load 'smartparens
      (sp-local-pair 'js2-mode "{" nil :post-handlers
                     '(:add
                       ("||\n[i]" "RET")
                       ("| " "SPC"))))

    (setq js2-basic-offset 2)

    (add-hook 'js2-mode-hook #'js2-refactor-mode)
    (add-hook 'js2-mode-hook (lambda ()
                               (setq mode-name "JS"))))

(add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . js2-jsx-mode))
(add-to-list 'interpreter-mode-alist '("node" . js2-mode))

(package-deferred-install 'json-mode
    :mode-entries '('("\\.json$"   . json-mode)
                    '("\\.jsonld$" . json-mode))
    :autoload-names '('json-mode
                      'json-mode-show-path
                      'json-mode-beautify))

;; =============================================================================
;; Shell Scripts ===============================================================
;; =============================================================================

;; bind zsh files to sh-mode
(add-to-list 'auto-mode-alist '("\\.zsh\\'" . sh-mode))

;; bind zsh files to the zsh submode of sh-mode
(with-eval-after-load 'sh-script
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'sh-script)))

  (add-hook 'sh-mode-hook
            (lambda ()
              (setq mode-name "sh")
              (if (string-match-p (rx ".zsh" line-end) buffer-file-name)
                  (sh-set-shell "zsh")))))

(package-deferred-install 'fish-mode
    :mode-entries '('("\\.fish\\'"           . fish-mode)
                    '("/fish_funced\\..*\\'" . fish-mode))
    :autoload-names '('fish_indent-before-save
                      'fish-mode)
    :manual-init
    (add-to-list 'interpreter-mode-alist '("fish" . fish-mode)))


;; =============================================================================
;; PowerShell Scripts ==========================================================
;; =============================================================================

(package-deferred-install 'powershell
    :mode-entries '('("\\.ps[dm]?1\\'" . powershell-mode))
    :autoload-names '('powershell-mode
                      'powershell)
    (setq powershell-indent 2)
    (sp-local-pair 'powershell-mode "`" nil :actions nil)
    (sp-local-pair 'powershell-mode "{" nil :post-handlers
                   '(:add
                     ("||\n[i]" "RET")
                     ("| " "SPC"))))

;; =============================================================================
;; Python ======================================================================
;; =============================================================================

(with-eval-after-load 'python
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'python)))

  (add-hook 'python-mode-hook
            (lambda ()
              ;; conflicts with `eldoc-mode'
              (semantic-idle-summary-mode -1)
              (setq mode-name "Py")))

  (package-deferred-install 'company-anaconda
      :autoload-names '('company-anaconda))

  (package-deferred-install 'anaconda-mode
      :autoload-names '('anaconda-mode)
      (diminish 'anaconda-mode " ✶")
    (setq anaconda-mode-installation-directory (locate-user-emacs-file
                                                "data/anaconda-mode"))

    (defun my/anaconda-eldoc-callback-fallback (docstring)
      (setq docstring
            (s-join " " (--map
                         (s-collapse-whitespace
                          (cdr (assoc 'docstring it)))
                         docstring)))
      (eldoc-message
       (substring docstring 0 (min (frame-width) (length docstring)))))

    (defun my/anaconda-eldoc-callback (result)
      (if result
          (eldoc-message (anaconda-mode-eldoc-format result))
        (anaconda-mode-call
         "goto_definitions"
         #'my/anaconda-eldoc-callback-fallback)))

    ;; also show object docstrings
    (defun nadvice/anaconda-mode-eldoc-function ()
      (anaconda-mode-call "eldoc" #'my/anaconda-eldoc-callback)
      nil)

    (advice-add 'anaconda-mode-eldoc-function :override
                #'nadvice/anaconda-mode-eldoc-function))

  (evil-define-key 'normal python-mode-map "gd" #'anaconda-mode-goto)
  (define-key python-mode-map (kbd "M-.") #'anaconda-mode-goto)
  (add-hook 'python-mode-hook #'anaconda-eldoc-mode)
  (add-hook 'python-mode-hook #'anaconda-mode)
  (add-hook 'python-mode-hook #'eldoc-mode)

  (package-deferred-install 'traad
      :autoload-names '('traad-open
                        'traad-close
                        'traad-running?
                        'traad-display-task-status
                        'traad-display-full-task-status
                        'traad-undo
                        'traad-redo
                        'traad-display-history
                        'traad-undo-info
                        'traad-redo-info
                        'traad-rename-current-file
                        'traad-rename
                        'traad-normalize-arguments
                        'traad-remove-argument
                        'traad-extract-method
                        'traad-extract-variable
                        'traad-organize-imports
                        'traad-expand-star-imports
                        'traad-froms-to-imports
                        'traad-relatives-to-absolutes
                        'traad-handle-long-imports
                        'traad-imports-super-smackdown
                        'traad-display-occurrences
                        'traad-display-implementations
                        'traad-goto-definition
                        'traad-findit
                        'traad-code-assist
                        'traad-display-calltip
                        'traad-popup-calltip
                        'traad-display-doc
                        'traad-popup-doc))

  (package-deferred-install 'live-py-mode
      :autoload-names '('live-py-mode))

  (package-deferred-install 'py-yapf
      :autoload-names '('py-yapf-buffer
                        'py-yapf-enable-on-save)))

(package-deferred-install 'django-mode
    :feature-name 'django-html-mode
    :mode-entries '('("\\.djhtml$" . django-html-mode))
    :autoload-names '('django-html-mode))

(package-deferred-install 'cython-mode
    :mode-entries '('("\\.pyx\\'" . cython-mode)
                    '("\\.pyd\\'" . cython-mode)
                    '("\\.pyi\\'" . cython-mode))
    :autoload-names '('cython-mode))

(package-deferred-install 'sage-shell-mode
    :mode-entries '('("\\.sage$" . sage-mode))
    :autoload-names '('run-sage
                      'run-new-sage
                      'sage-mode
                      'sage-shell:run-sage
                      'sage-shell:run-new-sage
                      'sage-shell:sage-mode)
    :regular-init (progn
                    (autoload 'run-sage "sage-shell-mode" nil t)
                    (autoload 'run-new-sage "sage-shell-mode" nil t)
                    (autoload 'sage-mode "sage-shell-mode" nil t))
    (setq sage-shell:use-prompt-toolkit t
          sage-shell-view-default-resolution 200)
    (sage-shell:define-alias)
    (evil-set-initial-state 'sage-shell-mode 'insert)

    (add-hook 'sage-shell-mode-hook #'eldoc-mode)
    (add-hook 'sage-mode-hook #'eldoc-mode)

    (add-hook 'sage-shell-mode-hook
              (lambda () (semantic-idle-summary-mode -1)))

    (add-hook 'sage-mode-hook
              (lambda () (semantic-idle-summary-mode -1)))

    (add-hook 'sage-shell-after-prompt-hook #'sage-shell-view)

    (defun nadvice/run-sage (old-fun &optional arg)
      (interactive "P")
      (if (called-interactively-p 'any)
          (cond
           ((consp arg)
            (call-interactively old-fun))
           (t
            (funcall old-fun "sage"))))
      (funcall old-fun arg))
    (advice-add 'run-sage :around #'nadvice/run-sage))

;; =============================================================================
;; Octave/MATLAB ===============================================================
;; =============================================================================

(with-eval-after-load 'octave
  (evil-set-initial-state 'inferior-octave-mode 'insert)

  (with-eval-after-load 'smartparens
    (sp-local-pair 'octave-mode "'" nil :actions nil)))

(add-to-list 'auto-mode-alist '("\\.m\\'" . octave-mode))

;; =============================================================================
;; Julia =======================================================================
;; =============================================================================

(package-deferred-install 'julia-mode
    :mode-entries '('("\\.jl\\'" . julia-mode))
    :autoload-names '('julia-mode
                      'inferior-julia
                      'run-julia)
    (evil-set-initial-state 'inferior-julia-mode 'insert)
    (add-hook 'inferior-julia-mode-hook (lambda ()
                                          (auto-indent-mode -1))))

;; =============================================================================
;; Haskell =====================================================================
;; =============================================================================

(package-deferred-install 'haskell-mode
    :feature-name 'haskell
    :mode-entries '('("\\.hcr\\'" . ghc-core-mode)
                    '("\\.dump-simpl\\'" . ghc-core-mode)
                    '("\\.ghci\\'" . ghci-script-mode)
                    '("\\.cabal\\'" . haskell-cabal-mode)
                    '("\\.[gh]s\\'" . haskell-mode)
                    '("\\.l[gh]s\\'" . literate-haskell-mode)
                    '("\\.hsc\\'" . haskell-mode))
    :autoload-names '('ghc-core-create-core
                      'ghc-core-mode
                      'ghci-script-mode
                      'interactive-haskell-mode
                      'haskell-interactive-mode-return
                      'haskell-session-kill
                      'haskell-interactive-kill
                      'haskell-session
                      'haskell-interactive-switch
                      'haskell-session-change
                      'haskell-kill-session-process
                      'haskell-interactive-mode-visit-error
                      'haskell-mode-contextual-space
                      'haskell-mode-jump-to-tag
                      'haskell-mode-after-save-handler
                      'haskell-interactive-bring
                      'haskell-process-load-file
                      'haskell-process-reload-file
                      'haskell-process-load-or-reload
                      'haskell-process-cabal-build
                      'haskell-process-cabal
                      'haskell-process-minimal-imports
                      'haskell-align-imports
                      'haskell-cabal-mode
                      'haskell-cabal-guess-setting
                      'haskell-cabal-get-dir
                      'haskell-cabal-visit-file
                      'haskell-process-restart
                      'haskell-process-clear
                      'haskell-process-interrupt
                      'haskell-process-touch-buffer
                      'haskell-describe
                      'haskell-rgrep
                      'haskell-process-do-info
                      'haskell-process-do-type
                      'haskell-mode-jump-to-def-or-tag
                      'haskell-mode-goto-loc
                      'haskell-mode-jump-to-def
                      'haskell-process-cd
                      'haskell-process-cabal-macros
                      'haskell-mode-show-type-at
                      'haskell-process-generate-tags
                      'haskell-process-unignore
                      'haskell-session-change-target
                      'haskell-mode-stylish-buffer
                      'haskell-mode-find-uses
                      'haskell-compile
                      'haskell-ds-create-imenu-index
                      'turn-on-haskell-decl-scan
                      'haskell-decl-scan-mode
                      'haskell-doc-mode
                      'haskell-doc-current-info
                      'haskell-doc-show-type
                      'turn-on-haskell-indent
                      'haskell-indent-mode
                      'haskell-indentation-mode
                      'turn-on-haskell-indentation
                      'haskell-interactive-mode-reset-error
                      'haskell-interactive-mode-echo
                      'haskell-process-show-repl-response
                      'haskell-process-reload-devel-main
                      'haskell-menu
                      'haskell-version
                      'haskell-mode-view-news
                      'haskell-mode
                      'haskell-forward-sexp
                      'literate-haskell-mode
                      'haskell-hoogle
                      'hoogle-lookup-from-local
                      'haskell-hayoo-url
                      'haskell-session-installed-modules
                      'haskell-session-all-modules
                      'haskell-session-project-modules
                      'haskell-move-nested
                      'haskell-move-nested-right
                      'haskell-move-nested-left
                      'haskell-navigate-imports
                      'haskell-navigate-imports-go
                      'haskell-navigate-imports-return
                      'haskell-session-maybe
                      'haskell-session-process
                      'haskell-simple-indent-mode
                      'turn-on-haskell-simple-indent
                      'haskell-sort-imports
                      'turn-on-haskell-unicode-input-method
                      'highlight-uses-mode
                      'inferior-haskell-load-file
                      'inferior-haskell-load-and-run
                      'inferior-haskell-send-decl
                      'inferior-haskell-type
                      'inferior-haskell-kind
                      'inferior-haskell-info
                      'inferior-haskell-find-definition
                      'inferior-haskell-find-haddock
                      'inf-haskell-mode)
    :manual-init
    (progn
      (add-to-list 'interpreter-mode-alist '("runghc" . haskell-mode))
      (add-to-list 'interpreter-mode-alist '("runhaskell" . haskell-mode))
      (add-to-list 'completion-ignored-extensions ".hi")))

;; =============================================================================
;; Web Development =============================================================
;; =============================================================================

(with-eval-after-load 'sgml-mode
  ;; after deleting a tag, indent properly
  (defun nadvice/sgml-delete-tag (&rest _args)
    (indent-region (point-min) (point-max)))

  (advice-add 'sgml-delete-tag :after #'nadvice/sgml-delete-tag))

(with-eval-after-load 'css-mode
  (sp-local-pair 'css-mode "{" nil :post-handlers
                 '(:add
                   ("||\n[i]" "RET")
                   ("| " "SPC"))))

(package-deferred-install 'company-web
    :autoload-names '('company-web-html))

(package-deferred-install 'web-mode
    :autoload-names '('web-mode)
    (setq web-mode-auto-close-style 1)
  (sp-local-pair 'web-mode "{" nil :post-handlers
                 '(:add
                   ("||\n[i]" "RET")
                   ("| " "SPC"))))

(package-deferred-install 'less-css-mode
    :mode-entries '('("\\.less\\'" . less-css-mode))
    :autoload-names '('less-css-mode 'less-css-compile)
    (sp-local-pair 'less-css-mode "{" nil :post-handlers
                   '(:add
                     ("||\n[i]" "RET")
                     ("| " "SPC"))))

(package-deferred-install 'scss-mode
    :mode-entries '('("\\.scss\\'" . scss-mode))
    :autoload-names '('scss-mode)
    (sp-local-pair 'scss-mode "{" nil :post-handlers
                   '(:add
                     ("||\n[i]" "RET")
                     ("| " "SPC"))))

(package-deferred-install 'sass-mode
    :mode-entries '('("\\.sass\\'" . sass-mode))
    :autoload-names '('sass-mode))

(package-deferred-install 'coffee-mode
    :mode-entries '('("\\.coffee\\'" . coffee-mode)
                    '("\\.iced\\'"   . coffee-mode)
                    '("Cakefile\\'"  . coffee-mode)
                    '("\\.cson\\'"   . coffee-mode))
    :autoload-names '('coffee-mode)
    :manual-init
    (add-to-list 'interpreter-mode-alist '("coffee" . coffee-mode)))

(package-deferred-install 'literate-coffee-mode
    :mode-entries '('("\\.litcoffee\\'" . litcoffee-mode)
                    '("\\.coffee.md\\'" . litcoffee-mode))
    :autoload-names '('litcoffee-mode))

(package-deferred-install 'livescript-mode
    :mode-entries '('("\\.ls\\'"     . livescript-mode)
                    '("Slakefile\\'" . livescript-mode))
    :autoload-names '('livescript-mode))

(package-deferred-install 'php-mode
    :mode-entries '('("\\.php[s345t]?\\'" . php-mode)
                    '("\\.phtml\\'"       . php-mode)
                    '("Amkfile"           . php-mode)
                    '("\\.amk$"           . php-mode))
    :autoload-names '('php-mode)
    :manual-init
    (add-to-list 'interpreter-mode-alist (cons "php" 'php-mode)))

(package-deferred-install 'dart-mode
    :autoload-names '('dart-mode))

(add-to-list 'auto-mode-alist '("\\.dart\\'" . dart-mode))

(package-deferred-install 'typescript-mode
    :autoload-names '('typescript-mode)
    :manual-init
  (eval-after-load 'folding
    '(when (fboundp 'folding-add-to-marks-list)
       (folding-add-to-marks-list 'typescript-mode "// {{{" "// }}}" )))
  (package-deferred-install 'tide
      :autoload-names '('tide-setup))
  (add-hook 'typescript-mode-hook #'tide-setup))

(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-mode))

(package-deferred-install 'handlebars-mode
    :mode-entries '('("\\.handlebars$" . handlebars-mode)
                    '("\\.hbs$"        . handlebars-mode))
    :autoload-names '('handlebars-mode))

(package-deferred-install 'impatient-mode
    :autoload-names '('impatient-mode))

;; =============================================================================
;; Dired =======================================================================
;; =============================================================================

(with-eval-after-load 'ls-lisp
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'ls-lisp)))
  (setq ls-lisp-use-insert-directory-program nil
        ls-lisp-support-shell-wildcards t
        ls-lisp-dirs-first t
        ls-lisp-verbosity nil))

(with-eval-after-load 'dired
  (require 'ls-lisp)
  (require 'dired-x)
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'dired)))
  (setq dired-listing-switches "-alh"
        dired-recursive-copies 'always
        dired-ls-F-marks-symlinks t
        dired-dwim-target t)

  (defun dired-first-file ()
    (interactive)
    (goto-char (point-min))
    (dired-next-line 4))

  (defun dired-last-file ()
    (interactive)
    (goto-char (point-max))
    (dired-next-line -1))

  (defun dired-up-directory ()
    "Take dired up one directory, but behave like dired-find-alternate-file"
    (interactive)
    (let ((old (current-buffer)))
      (dired-up-directory)
      (kill-buffer old)))

  (defun dired-enable-wdired ()
    (interactive)
    (unless (evil-insert-state-p)
      (evil-insert-state))
    (wdired-change-to-wdired-mode))

  (evil-define-key 'normal dired-mode-map "h" #'dired-up-directory)
  (evil-define-key 'normal dired-mode-map "l" #'dired-find-alternate-file)
  (evil-define-key 'normal dired-mode-map "j" #'dired-next-line)
  (evil-define-key 'normal dired-mode-map "k" #'dired-previous-line)

  (evil-define-key 'normal dired-mode-map "I" #'dired-enable-wdired)

  (evil-define-key 'normal dired-mode-map "o" #'dired-sort-toggle-or-edit)
  (evil-define-key 'normal dired-mode-map "m" #'dired-toggle-marks)
  (evil-define-key 'normal dired-mode-map "v" #'dired-mark)
  (evil-define-key 'normal dired-mode-map "V" #'dired-unmark)
  (evil-define-key 'normal dired-mode-map (kbd "C-v") #'dired-unmark-all-marks)
  (evil-define-key 'normal dired-mode-map "u" #'dired-undo)
  (evil-define-key 'normal dired-mode-map "c" #'dired-create-directory)

  (evil-define-key 'normal dired-mode-map "n" #'evil-search-next)
  (evil-define-key 'normal dired-mode-map "N" #'evil-search-previous)
  (evil-define-key 'normal dired-mode-map "q" #'kill-this-buffer)

  (define-key dired-mode-map (kbd "<remap> <beginning-of-buffer>")
    #'dired-first-file)
  (define-key dired-mode-map (kbd "<remap> <end-of-buffer>")
    #'dired-last-file))

(with-eval-after-load 'dired-aux
  (eval-when-compile (require 'dired-aux))
  (add-to-list 'dired-compress-file-suffixes '("\\.zip\\'" ".zip" "unzip")))

;; =============================================================================
;; Comint ======================================================================
;; =============================================================================

(with-eval-after-load 'comint
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'comint)))

  (setq comint-prompt-read-only t)

  (defun nadvice/comint-previous-matching-input-from-input (old-fun &rest args)
    (condition-case err
        (apply old-fun args)
      (user-error
       (if (string= (cadr err) "Not at command line")
           (cl-destructuring-bind (n &rest ignored) args
             (with-no-warnings
               (if (< n 0)
                   (next-line (- n))
                 (previous-line n))))
         (signal (car err) (cdr err))))))

  (advice-add 'comint-previous-matching-input-from-input
              :around
              #'nadvice/comint-previous-matching-input-from-input)

  (define-key comint-mode-map (kbd "<up>")
    #'comint-previous-matching-input-from-input)
  (define-key comint-mode-map (kbd "<down>")
    #'comint-next-matching-input-from-input))


;; =============================================================================
;; Scheme ======================================================================
;; =============================================================================
(package-deferred-install 'geiser
    :autoload-names '('geiser-version
                      'geiser-unload
                      'geiser-reload
                      'geiser
                      'run-geiser
                      'geiser-connect
                      'geiser-connect-local
                      'switch-to-geiser
                      'run-guile
                      'switch-to-guile
                      'connect-to-guile
                      'run-racket
                      'switch-to-racket
                      'connect-to-racket
                      'run-chicken
                      'switch-to-chicken
                      'connect-to-chicken
                      'geiser-mode
                      'turn-on-geiser-mode
                      'turn-off-geiser-mode
                      'geiser-mode--maybe-activate)
    :manual-init
  (progn (add-hook 'scheme-mode-hook 'geiser-mode--maybe-activate)
         (add-to-list 'auto-mode-alist '("\\.rkt\\'" . scheme-mode))))

(with-eval-after-load 'geiser-debug
  (evil-set-initial-state 'geiser-debug-mode 'insert))

(with-eval-after-load 'geiser-repl
  (evil-set-initial-state 'geiser-repl-mode 'emacs)
  (add-hook 'geiser-repl-mode-hook (lambda ()
                                     (auto-indent-mode -1))))

(package-deferred-install 'hy-mode
    :autoload-names '('hy-mode)
    :mode-entries '('("\\.hy\\'" . hy-mode))
    :manual-init
    (add-to-list 'interpreter-mode-alist '("hy" . hy-mode)))

;; =============================================================================
;; Shell modes =================================================================
;; =============================================================================
(eval-when-compile
  (with-demoted-errors "Load error: %s"
    (require 'hl-line)))

(defun my/generic-term-init ()
  ;; this disables key-chord-mode
  (set (make-local-variable 'input-method-function) nil)
  (adaptive-wrap-prefix-mode -1)
  (visual-line-mode -1)
  (yas-minor-mode -1)
  (setq yas-dont-activate t)

  (setq-local global-hl-line-mode nil)
  (setq-local scroll-margin 0)
  (setq-local smooth-scroll-margin 0))

(add-hook 'term-mode-hook #'my/generic-term-init)
(add-hook 'shell-mode-hook #'my/generic-term-init)
(add-hook 'eshell-mode-hook #'my/generic-term-init)

(with-eval-after-load 'term
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'term)))

  (defun nadvice/term-sentinel (old-fun &rest args)
    (cl-destructuring-bind (proc _msg) args
      (if (memq (process-status proc) '(signal exit))
          (let ((buffer (process-buffer proc)))
            (apply old-fun args)
            (kill-buffer buffer)
            (winner-undo)
            (message ""))
        (apply old-fun args))))
  (advice-add 'term-sentinel :around #'nadvice/term-sentinel)

  (define-key term-raw-map (kbd "<f12>") #'term-kill-subjob)
  (define-key term-raw-map (kbd "<remap> <cua-paste>") #'term-paste)

  (defun nadvice/term-exec-1 (name buffer command switches)
      (let* ((environment
              (list
               (format "TERM=%s" term-term-name)
               (format "TERMINFO=%s" data-directory)
               (format term-termcap-format "TERMCAP="
                       term-term-name term-height term-width)
               (format "EMACS=%s (term:%s)" emacs-version term-protocol-version)
               (format "INSIDE_EMACS=%s,term:%s" emacs-version term-protocol-version)
               (format "LINES=%d" term-height)
               (format "COLUMNS=%d" term-width)))
             (process-environment
              (append environment
                      process-environment))
             (tramp-remote-process-environment
              (append environment
                      tramp-remote-process-environment))
             (process-connection-type t)
             (coding-system-for-read 'binary))
        (apply 'start-file-process name buffer
           "/bin/sh" "-c"
           (format "stty -nl echo rows %d columns %d sane 2>/dev/null;\
    if [ $1 = .. ]; then shift; fi; exec \"$@\""
                   term-height term-width)
           ".."
           command switches)))

  (advice-add 'term-exec-1 :override #'nadvice/term-exec-1)

  (defun nadvice/ansi-term (args)
    (interactive "P")
    (cl-destructuring-bind (&optional program new-buffer-name) args
      (let ((default-shell
              (cl-some
               (if (tramp-tramp-file-p default-directory)
                   (lambda (shell)
                     (when shell
                       (with-parsed-tramp-file-name
                           buffer-file-name vec
                         (substring-no-properties
                          (tramp-find-executable
                           vec
                           (file-name-base shell)
                           (tramp-get-remote-path vec)
                           t t)))))
                 (lambda (shell)
                   (when (and shell
                              (file-exists-p shell))
                     shell)))
               (append
                (list (bound-and-true-p explicit-shell-file-name)
                      (getenv "ESHELL")
                      (getenv "SHELL"))
                (when (tramp-tramp-file-p default-directory)
                  (with-parsed-tramp-file-name
                      buffer-file-name vec
                    (or  (tramp-find-executable
                          vec "bash" (tramp-get-remote-path vec) t t)
                         (tramp-find-executable
                          vec "ksh" (tramp-get-remote-path vec) t t)
                         (tramp-get-connection-property
                          (tramp-get-connection-process vec) "remote-shell" nil)
                         (tramp-get-method-parameter
                          (tramp-file-name-method vec) 'tramp-remote-shell))))
                (list "/bin/sh")))))
        (if (consp program)
            (list (read-from-minibuffer "Run program: "
                                        default-shell)
                  new-buffer-name)
          (list default-shell new-buffer-name)))))

  (advice-add 'ansi-term :filter-args #'nadvice/ansi-term))

(defun eshell-kill-whole-line ()
  (interactive)
  (eshell-bol)
  (kill-line))

(defun my/eshell-onetime-setup ()
  (evil-define-key 'insert eshell-mode-map (kbd "<tab>") #'company-complete)
  (evil-define-key 'insert eshell-mode-map (kbd "C-a") #'eshell-bol)
  (evil-define-key 'insert eshell-mode-map (kbd "<home>") #'eshell-bol)
  (evil-define-key 'insert eshell-mode-map (kbd "<C-S-backspace>") #'eshell-kill-whole-line)
  (evil-define-key 'insert eshell-mode-map (kbd "C-r") #'eshell-isearch-backward)

  (remove-hook 'eshell-mode-hook #'my/eshell-onetime-setup))

(with-eval-after-load 'eshell
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'em-smart)
      (require 'em-unix)
      (require 'em-cmpl)
      (require 'company)))

  (add-hook 'eshell-mode-hook
            (lambda ()
              (setq-local company-idle-delay 0.1)
              (my/eshell-onetime-setup)))

  (add-hook 'eshell-directory-change-hook
            (lambda ()
              (setq company-idle-delay
                    (if (file-remote-p default-directory)
                        nil
                      0.1))))

  (setq eshell-cmpl-dir-ignore (rx line-start
                                   (or "." ".." "CVS" ".svn" ".git")
                                   line-end)
        eshell-cmpl-file-ignore (rx (or ".elc" ".zwc" ".pyc" "~" ".swp")
                                    line-end)
        eshell-cmpl-ignore-case t

        eshell-scroll-to-bottom-on-input t
        eshell-scroll-show-maximum-output nil
        eshell-cp-interactive-query t
        eshell-ln-interactive-query t
        eshell-mv-interactive-query t
        eshell-rm-interactive-query t
        eshell-mv-overwrite-files nil))

(defun eshell/clear ()
  (interactive)
  (let ((inhibit-read-only t)) (erase-buffer)))

(defun eshell/emacs (&rest args)
  "Invoke `find-file' on the file.
\"emacs +42 foo\" also goes to line 42 in the buffer."
  (while args
    (if (string-match (rx line-start "+" (group (one-or-more digit)) line-end)
                      (car args))
        (let* ((line (string-to-number (match-string 1 (pop args))))
               (file (pop args)))
          (find-file file)
          (forward-line line))
      (find-file (pop args)))))

(defun my/popup-ansi-term ()
  "Toggle a shell popup buffer with the current file's directory as cwd."
  (interactive)
  (let* ((dir (file-name-directory (or (buffer-file-name)
                                        ;; dired
                                        dired-directory
                                        ;; use HOME
                                        "~/")))
         (popup-buffer (get-buffer "*Popup Shell*"))
         (new-buffer (unless (buffer-live-p popup-buffer)
                       (save-window-excursion
                         (ansi-term (or explicit-shell-file-name
                                        (getenv "ESHELL")
                                        (getenv "SHELL")
                                        "/bin/sh")
                                    "*Popup Shell*")
                         (setq popup-buffer (get-buffer "*Popup Shell*")))
                       t)))

    (select-window (split-window-below))
    (switch-to-buffer popup-buffer)
    (unless new-buffer
      (comint-send-string nil (concat "cd " dir "; clear\n")))))

(global-set-key (kbd "<f12>") #'my/popup-ansi-term)

;; =============================================================================
;; Config file modes ===========================================================
;; =============================================================================

(package-deferred-install 'systemd
    :autoload-names '('systemd-mode)
    :manual-init
  (progn
    ;; Regexps stolen from:
    ;; https://github.com/holomorph/systemd-mode/blob/master/systemd.el
    (add-to-list 'auto-mode-alist `(,(eval-when-compile
                                       (rx (+? (any "a-zA-Z0-9-_.@\\"))
                                           "."
                                           (or "automount"
                                               "busname"
                                               "mount"
                                               "service"
                                               "slice"
                                               "socket"
                                               "swap"
                                               "target"
                                               "timer"
                                               "link"
                                               "netdev"
                                               "network")
                                           string-end))
                                    . systemd-mode))
    (add-to-list 'auto-mode-alist `(,(eval-when-compile
                                       (rx ".#"
                                           (or (and (+? (any "a-zA-Z0-9-_.@\\"))
                                                    "."
                                                    (or "automount"
                                                        "busname"
                                                        "mount"
                                                        "service"
                                                        "slice"
                                                        "socket"
                                                        "swap"
                                                        "target"
                                                        "timer"
                                                        "link"
                                                        "netdev"
                                                        "network"))
                                               "override.conf")
                                           (= 16 (char hex-digit))
                                           string-end))
                                    . systemd-mode))
    (add-to-list 'auto-mode-alist `(,(rx "/systemd/"
                                         (+? anything)
                                         ".d/"
                                         (+? (not (any ?/)))
                                         ".conf"
                                         string-end)
                                    . systemd-mode))))

(package-deferred-install 'gitattributes-mode
    :mode-entries '('("/\\.gitattributes\\'"       . gitattributes-mode)
                    '("/\\.git/info/attributes\\'" . gitattributes-mode)
                    '("/git/attributes\\'"         . gitattributes-mode))
    :autoload-names '('gitattributes-mode))

(package-deferred-install 'gitconfig-mode
    :mode-entries '('("/\\.gitconfig\\'"  . gitconfig-mode)
                    '("/\\.git/config\\'" . gitconfig-mode)
                    '("/git/config\\'"    . gitconfig-mode)
                    '("/\\.gitmodules\\'" . gitconfig-mode))
    :autoload-names '('gitconfig-mode))

(package-deferred-install 'gitignore-mode
    :mode-entries '('("/\\.gitignore\\'"        . gitignore-mode)
                    '("/\\.git/info/exclude\\'" . gitignore-mode)
                    '("/git/ignore\\'"          . gitignore-mode))
    :autoload-names '('gitignore-mode))

(package-deferred-install 'ssh-config-mode
    :mode-entries '('(".ssh/config\\'"       . ssh-config-mode)
                    '("sshd?_config\\'"      . ssh-config-mode)
                    '("known_hosts\\'"       . ssh-known-hosts-mode)
                    '("authorized_keys2?\\'" . ssh-authorized-keys-mode))
    :autoload-names '('ssh-config-mode 'ssh-authorized-keys-mode))

(package-deferred-install 'pkgbuild-mode
    :mode-entries '('("/PKGBUILD\\'" . pkgbuild-mode))
    :autoload-names '('pkgbuild-mode))

(package-deferred-install 'chrontab-mode
    :mode-entries '('("\\.cron\\(tab\\)?\\'" . crontab-mode))
    :autoload-names '('chrontab-mode))

(package-deferred-install 'dockerfile-mode
    :mode-entries '('("Dockerfile.*\\'" . dockerfile-mode))
    :autoload-names '('dockerfile-build-buffer
                      'dockerfile-build-no-cache-buffer
                      'dockerfile-mode))

(package-deferred-install 'cmake-mode
    :mode-entries '('("CMakeLists\\.txt\\'" . cmake-mode)
                    '("\\.cmake\\'"         . cmake-mode))
    :autoload-names '('cmake-mode
                      'cmake-command-run
                      'cmake-help-list-commands
                      'cmake-help-command
                      'cmake-help-module
                      'cmake-help-variable
                      'cmake-help-property
                      'cmake-help))

;; Qt qmake project files
(add-to-list 'auto-mode-alist '("\\.pro\\'" . makefile-mode))

(package-deferred-install 'hgignore-mode
    :mode-entries '('("\\.hgignore\\'" . hgignore-mode))
    :autoload-names '('hgignore-mode))

(package-deferred-install 'nginx-mode
    :mode-entries '('("nginx\\.conf\\'"     . nginx-mode)
                    '("/nginx/.+\\.conf\\'" . nginx-mode))
    :autoload-names '('nginx-mode))

;; =============================================================================
;; Markup modes ================================================================
;; =============================================================================

(package-deferred-install 'yaml-mode
    :mode-entries '('("\\.e?ya?ml$" . yaml-mode))
    :autoload-names '('yaml-mode))

(package-deferred-install 'haml-mode
    :mode-entries '('("\\.haml\\'" . haml-mode))
    :autoload-names '('haml-mode))

(package-deferred-install 'markdown-mode
    :mode-entries '('("\\.text\\'" . markdown-mode)
                    '("\\.md\\'"   . markdown-mode))
    :autoload-names '('markdown-mode 'gfm-mode))

(package-deferred-install 'bbcode-mode
    :mode-entries '('("\\.bbcode$" . bbcode-mode))
    :autoload-names '('bbcode-mode))

;; =============================================================================
;; TeX/LaTeX ===================================================================
;; =============================================================================

(package-deferred-install 'company-math
    :autoload-names '('company-latex-commands
                      'company-math-symbols-latex
                      'company-math-symbols-unicode))

(package-deferred-install 'auctex
    :mode-entries '('("\\.drv\\'" . latex-mode)
                    '("\\.hva\\'" . latex-mode)
                    '("\\.dtx\\'" . doctex-mode))
    :autoload-names '('bib-cite-minor-mode
                      'turn-on-bib-cite
                      'ConTeXt-mode
                      'context-mode
                      'context-en-mode
                      'context-nl-mode
                      'font-latex-setup
                      'BibTeX-auto-store
                      'TeX-latex-mode
                      'docTeX-mode
                      'TeX-doctex-mode
                      'multi-prompt-key-value
                      'TeX-plain-tex-mode
                      'ams-tex-mode
                      'preview-install-styles
                      'LaTeX-preview-setup
                      'preview-report-bug
                      'TeX-assoc-string
                      'TeX-tex-mode
                      'TeX-auto-generate
                      'TeX-auto-generate-global
                      'TeX-submit-bug-report
                      'TeX-install-toolbar
                      'LaTeX-install-toolbar
                      'TeX-fold-mode
                      'tex-fold-mode
                      'tex-font-setup
                      'Texinfo-mode
                      'TeX-texinfo-mode
                      'japanese-plain-tex-mode
                      'japanese-latex-mode
                      'texmathp
                      'texmathp-match-switch
                      'toolbarx-install-toolbar)
    :manual-init
    (progn
      (advice-add 'tex-mode :override #'TeX-tex-mode)
      (advice-add 'plain-tex-mode :override #'TeX-plain-tex-mode)
      (advice-add 'texinfo-mode :override #'TeX-texinfo-mode)
      (advice-add 'latex-mode :override #'TeX-latex-mode)
      (advice-add 'doctex-mode :override #'TeX-doctex-mode)))

(with-eval-after-load 'tex
  (package-deferred-install 'magic-latex-buffer
      :autoload-names '('magic-latex-buffer)
      (setq magic-latex-enable-block-align nil))

  (package-deferred-install '(company-auctex :repo "PythonNut/company-auctex"
                                             :fetcher github)
      :feature-name 'company-auctex
      :autoload-names '('company-auctex-symbols
                        'company-auctex-environments))

  (with-eval-after-load 'evil
    (package-deferred-install '(evil-latex-textobjects
                                :repo "hpdeifel/evil-latex-textobjects"
                                :fetcher github
                                :files ("evil-latex-textobjects.el"))
        :feature-name 'evil-latex-textobjects
        :autoload-names '('evil-latex-textobjects-mode
                          'turn-on-evil-latex-textobjects-mode
                          'turn-off-evil-latex-textobjects-mode))

    (add-hook 'LaTeX-mode-hook 'turn-on-evil-latex-textobjects-mode))

  (setq TeX-auto-save t
        TeX-save-query nil
        TeX-parse-self t
        TeX-PDF-mode t
        TeX-source-correlate-start-server t)

  (evil-set-initial-state 'TeX-error-overview-mode 'insert)

  (add-hook 'LaTeX-mode-hook (lambda ()
                               (adaptive-wrap-prefix-mode -1)))
  (add-hook 'LaTeX-mode-hook 'TeX-source-correlate-mode)
  (add-hook 'LaTeX-mode-hook 'magic-latex-buffer)
  (add-to-list 'TeX-output-view-style '("^pdf$" "." "evince --page-index=%(outpage) %o"))

  (defun nadvice/TeX-command-master (old-fun arg)
    (interactive "P")
    (if (called-interactively-p 'any)
        (if (consp arg)
            (call-interactively old-fun)
          (cl-letf* (((symbol-function #'TeX-command-query)
                      (lambda (name)
                        (TeX-command-default name)
                        (car-safe (TeX-assoc "LaTeX" TeX-command-list)))))
            (call-interactively old-fun)))
      (apply old-fun args)))

  (advice-add 'TeX-command-master :around #'nadvice/TeX-command-master)

  (defun my/embrace-with-TeX-environment ()
    (let* ((input (read-string "Environment: ")))
      (cons (format "\\begin{%s}" (or input "") )
            (format "\\end{%s}" (or input "")))))

  (defun my/embrace-TeX-setup ()
    (require 'embrace)
    (embrace-add-pair ?= "\\verb|" "|")
    (embrace-add-pair ?~ "\\texttt{" "}")
    (embrace-add-pair ?/ "\\emph{" "}")
    (embrace-add-pair ?* "\\textbf{" "}")
    (embrace-add-pair ?$ "$" "$")
    (embrace-add-pair ?\\ "\\[" "\\]")
    (embrace-add-pair-regexp ?e "\\\\begin{[^\}]*?}" "\\\\end{[^\}]*?}"
                             'my/embrace-with-TeX-environment
                             (embrace-build-help "\\begin{env}" "\\end{env}")))

  (add-hook 'LaTeX-mode-hook #'my/embrace-TeX-setup))

;; =============================================================================
;; Org mode ====================================================================
;; =============================================================================

(with-eval-after-load 'ob-core
  (setq org-confirm-babel-evaluate nil)
  (add-hook 'org-babel-after-execute-hook 'org-display-inline-images)

  ;; Load languages when needed
  (defun nadvice/org-babel-execute-src-block (old-fun &rest args)
    (let ((language (org-element-property :language (org-element-at-point))))
      (unless (cdr (assoc (intern language) org-babel-load-languages))
        (add-to-list 'org-babel-load-languages (cons (intern language) t))
        (org-babel-do-load-languages 'org-babel-load-languages org-babel-load-languages))
      (apply old-fun args)))

  (advice-add 'org-babel-execute-src-block :around
              #'nadvice/org-babel-execute-src-block))

(with-eval-after-load 'org
  (setq org-src-fontify-natively t
        org-startup-with-inline-images t)

  (defvar ob-language-file-alist
    (list '(ob-sage . ob-sagemath))
    "An alist that resolves discrepancies between language names and file names in org-babel")

  (defvar ob-deferred-install-languages (list 'ob-axiom
                                              'ob-browser
                                              'ob-coffee
                                              'ob-cypher
                                              'ob-diagrams
                                              'ob-elixir
                                              'ob-go
                                              'ob-http
                                              'ob-hy
                                              'ob-ipython
                                              'ob-kotlin
                                              'ob-lfe
                                              'ob-lua
                                              'ob-mongo
                                              'ob-ml-marklogic
                                              'ob-php
                                              'ob-prolog
                                              'ob-redis
                                              'ob-restclient
                                              'ob-sagemath
                                              'ob-scala
                                              'ob-sly
                                              'ob-sml
                                              'ob-swift
                                              'ob-translate
                                              'ob-typescript)
    "A list of org-babel backends that can be installed with package.el")

  (defun nadvice/org-babel-do-load-languages (old-fun &rest args)
    (cl-letf* ((old-require (symbol-function #'require))
               ((symbol-function #'require)
                (lambda (symbol &rest iargs)
                  (let ((symbol
                         (cdr (or (assoc symbol ob-language-file-alist)
                                  (cons symbol symbol)))))
                    (when (and (not (funcall old-require
                                             symbol
                                             (car-safe iargs)
                                             t))
                               (member symbol
                                       ob-deferred-install-languages))
                      (package-install symbol)
                      (apply old-require symbol iargs))))))
      (apply old-fun args)))

  (advice-add 'org-babel-do-load-languages :around
              #'nadvice/org-babel-do-load-languages))

;; =============================================================================
;; R ===========================================================================
;; =============================================================================

(package-deferred-install 'ess
    :mode-entries '('("\\.R$" . R-mode))
    :autoload-names '('R
                      'R-mode
                      'S))

;; =============================================================================
;; Polymodes ===================================================================
;; =============================================================================

(package-deferred-install 'polymode
    :autoload-names '('poly-markdown-mode
                      'poly-noweb+r-mode
                      'poly-noweb+r-mode
                      'poly-markdown+r-mode
                      'poly-rapport-mode
                      'poly-html+r-mode
                      'poly-brew+r-mode
                      'poly-r+c++-mode
                      'poly-c++r-mode
                      'poly-javascript+erb-mode
                      'poly-coffee+erb-mode
                      'poly-html+erb-mode
                      'poly-slim-mode))

(with-eval-after-load 'polymode
  (require 'poly-R)
  (require 'poly-erb)
  (require 'poly-markdown)
  (require 'poly-noweb)
  (require 'poly-slim))

;;; MARKDOWN
(add-to-list 'auto-mode-alist '("\\.md$" . poly-markdown-mode))

;;; R related modes
(add-to-list 'auto-mode-alist '("\\.Snw$" . poly-noweb+r-mode))
(add-to-list 'auto-mode-alist '("\\.Rnw$" . poly-noweb+r-mode))
(add-to-list 'auto-mode-alist '("\\.Rmd$" . poly-markdown+r-mode))
(add-to-list 'auto-mode-alist '("\\.rapport$" . poly-rapport-mode))
(add-to-list 'auto-mode-alist '("\\.Rhtml$" . poly-html+r-mode))
(add-to-list 'auto-mode-alist '("\\.Rbrew$" . poly-brew+r-mode))
(add-to-list 'auto-mode-alist '("\\.Rcpp$" . poly-r+c++-mode))
(add-to-list 'auto-mode-alist '("\\.cppR$" . poly-c++r-mode))

;;; ERB modes
(add-to-list 'auto-mode-alist '("\\.js.erb$" . poly-javascript+erb-mode))
(add-to-list 'auto-mode-alist '("\\.coffee.erb$" . poly-coffee+erb-mode))
(add-to-list 'auto-mode-alist '("\\.html.erb$" . poly-html+erb-mode))

;;; Slim mode
(add-to-list 'auto-mode-alist '("\\.slim$" . poly-slim-mode))

;; =============================================================================
;; Speculative languages =======================================================
;; =============================================================================

(package-deferred-install 'csharp-mode
    :mode-entries '('("\\.cs\\'" . csharp-mode))
    :autoload-names '('csharp-mode))

(package-deferred-install 'clojure-mode
    :mode-entries '('("\\.clj\\|dtm\\|edn\\'" . clojure-mode)
                    '("\\.cljc\\'" . clojurec-mode)
                    '("\\.cljx\\'" . clojurex-mode)
                    '("\\.cljs\\'" . clojurescript-mode)
                    '("\\(?:build\\|profile\\)\\.boot\\'" . clojure-mode))
    :autoload-names '('clojure-mode
                      'clojurescript-mode
                      'clojurec-mode
                      'clojurex-mode))

(package-deferred-install 'd-mode
    :autoload-names '('d-mode))

(add-to-list 'auto-mode-alist '("\\.d[i]?\\'" . d-mode))

(package-deferred-install 'go-mode
    :mode-entries '('("\\.go\\'" . go-mode))
    :autoload-names '('go-mode
                      'gofmt-before-save
                      'godoc
                      'go-download-play)
    (package-deferred-install 'company-go
        :autoload-names '('company-go)))

(package-deferred-install 'swift-mode
    :mode-entries '('("\\.swift\\'" . swift-mode))
    :autoload-names '('swift-mode
                      'swift-mode-run-repl))

(package-deferred-install 'rust-mode
    :mode-entries '('("\\.rs\\'" . rust-mode))
    :autoload-names '('rust-mode))

(package-deferred-install 'lua-mode
    :mode-entries '('("\\.lua$" . lua-mode))
    :autoload-names '('lua-mode
                      'run-lua
                      'lua-start-process)
    :manual-init
    (add-to-list 'interpreter-mode-alist '("lua" . lua-mode)))

(package-deferred-install 'vimrc-mode
    :mode-entries '('("\\.vim\\'" . vimrc-mode)
                    '("[._]?g?vimrc\\'" . vimrc-mode)
                    '("\\.exrc\\'" . vimrc-mode))
    :autoload-names '('vimrc-mode))

(package-deferred-install 'csv-mode
    :mode-entries '('("\\.[Cc][Ss][Vv]\\'" . csv-mode))
    :autoload-names '('csv-mode))

(package-deferred-install 'batch-mode
    :autoload-names '('batch-mode))

(add-to-list 'auto-mode-alist '("\\.bat\\'" . batch-mode))
(add-to-list 'auto-mode-alist '("\\.cmd\\'" . batch-mode))

(package-deferred-install 'j-mode
    :mode-entries '('("\\.ij[rstp]$" . j-mode))
    :autoload-names '('j-mode))

(package-deferred-install 'jinja2-mode
    :mode-entries '('("\\.jinja2\\'" . jinja2-mode))
    :autoload-names '('jinja2-mode))

(package-deferred-install 'scala-mode2
    :mode-entries '('("\\.\\(scala\\|sbt\\)\\'" . scala-mode))
    :autoload-names '('scala-mode:set-scala-syntax-mode
                      'scala-mode:goto-start-of-code
                      'scala-mode))

(package-deferred-install 'vala-mode
    :mode-entries '('("\\.vala$" . vala-mode))
    :autoload-names '('vala-mode))

(package-deferred-install 'fsharp-mode
    :mode-entries '('("\\.fs[iylx]?$" . fsharp-mode))
    :autoload-names '('fsharp-mode))

(package-deferred-install 'elixir-mode
    :mode-entries '('("\\.elixir\\'" . elixir-mode)
                    '("\\.ex\\'"     . elixir-mode)
                    '("\\.exs\\'"    . elixir-mode))
    :autoload-names '('elixir-mode-open-modegithub
                      'elixir-mode-open-elixir-home
                      'elixir-mode-open-docs-master
                      'elixir-mode-open-docs-stable
                      'elixir-mode-version))

(package-deferred-install 'gnuplot
    :autoload-names '('gnuplot-mode
                      'gnuplot-make-buffer
                      'run-gnuplot) )

(add-to-list 'auto-mode-alist '("\\.gp$" . gnuplot-mode))

(package-deferred-install 'dylan-mode
    :mode-entries '('("\\.dylan\\'" . dylan-mode))
    :autoload-names '('dylan-mode))

(package-deferred-install 'dylan-mode
    :mode-entries '('("\\.lid\\'" . dylanlid-mode))
    :feature-name 'dylanlid-mode
    :autoload-names '('dylanlid-mode))

(package-deferred-install 'processing-mode
    :autoload-names '('processing-find-sketch
                      'processing-mode))

(package-deferred-install 'actionscript-mode
    :mode-entries '('("\\.as\\'" . actionscript-mode))
    :autoload-names '('actionscript-mode))

(package-deferred-install 'puppet-mode
    :mode-entries '('("\\.pp\\'" . puppet-mode))
    :autoload-names '('puppet-mode))

(package-deferred-install 'puppetfile-mode
    :mode-entries '('("Puppetfile\\'" . puppetfile-mode))
    :autoload-names '('puppetfile-mode))

(package-deferred-install 'gap-mode
    :mode-entries '('("\\.\\(g\\(?:ap\\|[di]\\)?\\)\\'" . gap-mode))
    :autoload-names '('gap-mode))

(package-deferred-install 'perl6-mode
    :mode-entries '('("\\.p[lm]?6\\'" . perl6-mode))
    :autoload-names '('perl6-mode)
    :manual-init
    (add-to-list 'interpreter-mode-alist '("perl6" . perl6-mode)))

(package-deferred-install 'fstar-mode
    :mode-entries '('("\\.fsti?\\'" . fstar-mode))
    :autoload-names '('fstar-mode))

(package-deferred-install 'sml-mode
    :mode-entries '('("\\.s\\(ml\\|ig\\)\\'" . sml-mode)
                    '("\\.cm\\'" . sml-cm-mode)
                    '("\\.grm\\'" . sml-yacc-mode))
    :autoload-names '('run-sml
                      'sml-run
                      'sml-mode
                      'sml-cm-mode
                      'sml-lex-mode
                      'sml-yacc-mode)
    :manual-init
    (progn
      (add-to-list 'completion-ignored-extensions ".cm/")
      (add-to-list 'completion-ignored-extensions "CM/")))

(package-deferred-install 'salt-mode
    :mode-entries '('("\\.sls\\'" . salt-mode))
    :autoload-names '('salt-mode))


(package-deferred-install 'ahk-mode
    :mode-entries '('("\\.ahk\\'" . ahk-mode))
    :autoload-names '('ahk-mode))

(provide 'config-modes)
