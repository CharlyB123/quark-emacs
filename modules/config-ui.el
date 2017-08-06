;; -*- lexical-binding: t -*-
(require 'cl-lib)

(require 'config-avy-easymotion)
(require 'config-undo)

(require 'config-smartparens)
(require 'config-rainbow-delimiters)

(require 'config-hydras)

(setq mouse-wheel-scroll-amount '(3 ((shift) . 1))
      mouse-wheel-progressive-speed nil
      mouse-wheel-follow-mouse t
      smooth-scroll-margin 5
      scroll-step 1
      auto-window-vscroll nil
      scroll-conservatively 1000)

(defun isearch-exit-chord-worker ()
  "Exit out of isearch after a chord"
  (interactive)
  (isearch-delete-char)
  (isearch-exit))

(eval-when-compile
  (with-demoted-errors "Load error: %s"
    (require 'hydra)))

(defhydra my/smart-isearch-chord-hydra
  (:timeout key-chord-one-key-delay
            :pre (setq hydra-is-helpful nil)
            :post (setq hydra-is-helpful t))
  ("j" isearch-exit-chord-worker)
  ("k" isearch-exit-chord-worker))

(defun isearch-exit-chord ()
  (interactive)
  (isearch-printing-char)
  (my/smart-isearch-chord-hydra/body))

(define-key isearch-mode-map "j" #'isearch-exit-chord)
(define-key isearch-mode-map "k" #'isearch-exit-chord)

(use-package smooth-scrolling
  :config
  (smooth-scrolling-mode +1))

(use-package multiple-cursors
  :commands (mc/mark-lines
             mc/mark-next-lines
             mc/mark-previous-lines
             mc/unmark-next-like-this
             mc/unmark-previous-like-this
             mc/skip-to-previous-like-this
             mc/mark-all-like-this
             mc/mark-all-words-like-this
             mc/mark-all-symbols-like-this
             mc/mark-all-in-region
             mc/mark-all-in-region-regexp
             mc/mark-more-like-this-extended
             mc/mmlte--up
             mc/mmlte--down
             mc/mmlte--left
             mc/mmlte--right
             mc/mark-all-like-this-dwim
             mc/mark-all-dwim
             mc/mark-all-like-this-in-defun
             mc/mark-all-words-like-this-in-defun
             mc/mark-all-symbols-like-this-in-defun
             mc/add-cursor-on-click
             mc/mark-sgml-tag-pair
             mc/mark-pop
             set-rectangular-region-anchor
             rrm/switch-to-multiple-cursors
             mc/insert-numbers
             mc/reverse-regions
             mc/sort-regions
             hum/keyboard-quit
             mc-hide-unmatched-lines-mode)
  :config
  (setq mc/list-file (locate-user-emacs-file "data/.mc-lists.el"))

  ;; This is required to load the save file, due to a poor design
  ;; decision in multiple-cursors.el
  (load mc/list-file t)

  (define-key mc/keymap (kbd "<return>") nil)
  (define-key mc/keymap (kbd "C-c <return>") 'multiple-cursors-mode))

(global-set-key (kbd "C-c l") #'mc/edit-lines)
(global-set-key (kbd "C-c a") #'mc/mark-all-dwim)
(global-set-key (kbd "C->") #'mc/mark-next-like-this)
(global-set-key (kbd "C-<") #'mc/mark-previous-like-this)
(global-set-key (kbd "C-?") #'mc/mark-all-dwim)
(global-set-key (kbd "C-c >") #'mc/mark-next-like-this)
(global-set-key (kbd "C-c <") #'mc/mark-previous-like-this)
(global-set-key (kbd "C-c ?") #'mc/mark-all-dwim)

;; directional window movement
(if (display-graphic-p)
    (progn
      (global-set-key (kbd "<M-left>")  #'windmove-left)
      (global-set-key (kbd "<M-right>") #'windmove-right)
      (global-set-key (kbd "<M-up>")    #'windmove-up)
      (global-set-key (kbd "<M-down>")  #'windmove-down))

  (global-set-key (kbd "<C-left>")  #'windmove-left)
  (global-set-key (kbd "<C-right>") #'windmove-right)
  (global-set-key (kbd "<C-up>")    #'windmove-up)
  (global-set-key (kbd "<C-down>")  #'windmove-down))

(use-package framemove
  :init
  (defun my/framemove-onetime-setup (&optional frame)
    (with-selected-frame (or frame (selected-frame))
      (require 'framemove)
      (remove-hook 'before-make-frame-hook #'my/framemove-onetime-setup)))

  ;; directional frame movement too
  (add-hook 'emacs-startup-hook
            (lambda ()
              (add-hook 'before-make-frame-hook #'my/framemove-onetime-setup)))

  :config
  (setq framemove-hook-into-windmove t))

(defun pop-window-into-frame ()
  (interactive)
  (let ((buffer (current-buffer)))
    (unless (one-window-p)
      (delete-window))
    (display-buffer-pop-up-frame buffer nil)))

;;; ====================================
;;; iflib - switch buffers alt-tab style
;;; ====================================
(use-package iflipb
  :config
  (setq iflipb-ignore-buffers (list (rx line-start " ")
                                    (rx line-start "*helm")
                                    (rx line-start "*Compile")
                                    (rx line-start "*Quail"))
        iflipb-wrap-around 't))

(global-set-key (kbd "<C-tab>") #'iflipb-next-buffer)
(global-set-key (kbd "C-S-<iso-lefttab>") #'iflipb-previous-buffer)

(global-set-key (kbd "C-c TAB") #'iflipb-next-buffer)
(global-set-key (kbd "C-c <backtab>") #'iflipb-previous-buffer)

;; also allow undo/redo on window configs
(add-hook 'window-configuration-change-hook #'winner-mode)

(use-package volatile-highlights
	     :ensure t
  :init
  (defun my/vhl-onetime-setup ()
    (remove-hook 'first-change-hook #'my/vhl-onetime-setup))

  (add-hook 'emacs-startup-hook
            (lambda ()
              (add-hook 'first-change-hook #'my/vhl-onetime-setup)))
  :config
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'volatile-highlights)))

  (diminish #'volatile-highlights-mode)
  (vhl/define-extension 'my-evil-highlights
                        'evil-yank
                        'evil-paste-after
                        'evil-paste-before
                        'evil-move)

  (vhl/install-extension 'my-evil-highlights)

  (vhl/define-extension 'my-undo-tree-highlights
                        'undo-tree-undo
                        'undo-tree-redo)

  (vhl/install-extension 'my-undo-tree-highlights)

  (volatile-highlights-mode +1))

(use-package auto-highlight-symbol
  :init
  (unless (or (bound-and-true-p my/slow-device)
              (< (display-color-cells) 256))
    (require 'auto-highlight-symbol)
    (global-auto-highlight-symbol-mode +1))

  :config
  (setq ahs-idle-interval 0.3)
  (add-to-list 'ahs-inhibit-face-list 'font-lock-keyword-face)
  (add-to-list 'ahs-inhibit-face-list 'region)
  (add-to-list 'ahs-inhibit-face-list 'isearch)

  (define-key auto-highlight-symbol-mode-map (kbd "<M-left>") nil)
  (define-key auto-highlight-symbol-mode-map (kbd "<M-right>") nil)
  (define-key auto-highlight-symbol-mode-map (kbd "M--") nil)

  (defun my/ahs-setup-faces ()
    (if (display-graphic-p)
        (progn
          (set-face-attribute 'ahs-plugin-defalt-face nil
                              :foreground nil
                              :background nil)
          (set-face-attribute 'ahs-face nil
                              :foreground nil
                              :background "#073642")
          (set-face-attribute 'ahs-definition-face nil
                              :foreground nil
                              :background "#073642"
                              :underline '(:color "#268bd2")))

      (set-face-attribute 'ahs-plugin-defalt-face nil
                          :foreground nil
                          :background "grey20")
      (set-face-attribute 'ahs-face nil
                          :foreground nil
                          :background "grey20")
      (set-face-attribute 'ahs-definition-face nil
                          :foreground nil
                          :background "grey20"
                          :underline '(:color "#268bd2")))

    (set-face-attribute 'ahs-warning-face nil
                        :foreground nil
                        :underline '(:color "yellow"))
    (set-face-attribute 'ahs-plugin-bod-face nil
                        :foreground nil
                        :underline '(:color "purple"))
    (set-face-attribute 'ahs-plugin-whole-buffer-face nil
                        :foreground nil
                        :underline '(:color "black")))

  (add-hook 'load-theme-hook #'my/ahs-setup-faces)

  (add-hook 'auto-highlight-symbol-mode-hook
            (lambda ()
              (diminish 'auto-highlight-symbol-mode))))

;; ==================
;; Visible whitespace
;; ==================

(with-eval-after-load 'whitespace
  (setq whitespace-display-mappings '((space-mark 32 [?·]))
        whitespace-style '(face trailing spaces space-mark))

  (set-face-attribute 'whitespace-space nil
                      :inherit nil
                      :foreground (face-background 'default)
                      :background nil)

  (set-face-attribute 'whitespace-trailing nil
                      :inherit 'avy-background-face
                      :background nil
                      :inverse-video nil
                      :foreground nil)

  (defun nadvice/whitespace-trailing-regexp (limit)
    "Match all trailing spaces. This overloads the definition in whitespace.el."
    (let ((status t))
      (while (unless (re-search-forward whitespace-trailing-regexp limit t)
               (setq status nil)))          ;; end of buffer
      status))
  (advice-add 'whitespace-trailing-regexp :override
              #'nadvice/whitespace-trailing-regexp))

;; ============
;; Line numbers
;; ============

;; column numbers too
(column-number-mode +1)

(use-package linum
  :ensure nil
  :init
  (defun linum-cycle ()
    (interactive)
    (if (bound-and-true-p global-linum-mode)
        (if (eq linum-format 'dynamic)
            (global-linum-mode -1)
          (setq linum-format 'dynamic))
      (progn
        (global-linum-mode +1)
        (setq linum-format 'linum-relative))))

  (global-set-key (kbd "C-c L") #'linum-cycle)
  (global-set-key (kbd "C-c C-l") #'linum-cycle)
  :config
  (setq linum-delay t)

  (set-face-background 'linum nil)


  (use-package linum-relative
    :config
    (setq linum-relative-current-symbol ""
          linum-relative-format "%3s ")

    (set-face-attribute 'linum-relative-current-face nil
                        :weight 'extra-bold
                        :foreground nil
                        :background nil
                        :inherit '(hl-line default))

    ;; truncate current line to three digits
    (defun nadvice/linum-relative (line-number)
      (let* ((diff1 (abs (- line-number linum-relative-last-pos)))
             (diff (if (< diff1 0)
                       diff1
                     (+ diff1 linum-relative-plusp-offset)))
             (current-p (= diff linum-relative-plusp-offset))
             (current-symbol (if (and linum-relative-current-symbol current-p)
                                 (if (string= "" linum-relative-current-symbol)
                                     (number-to-string (% line-number 1000))
                                   linum-relative-current-symbol)
                               (number-to-string diff)))
             (face (if current-p 'linum-relative-current-face 'linum)))
        (propertize (format linum-relative-format current-symbol) 'face face)))

    (advice-add 'linum-relative :override #'nadvice/linum-relative)))

(use-package which-key
  :init (which-key-mode +1)
  :diminish which-key-mode
  :config
  (setq which-key-sort-order nil
        which-key-side-window-max-height 0.33)

  (add-to-list 'which-key-description-replacement-alist
               `(,(rx "evil-"
                      (or "a" "an" "inner")
                      "-"
                      (group (zero-or-more not-newline)))
                 . "\\1")))

;; add intelligent buffer renaming
(defun rename-current-buffer-file ()
  "Renames current buffer and file it is visiting."
  (interactive)
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not (and filename (file-exists-p filename)))
        (error "Buffer '%s' is not visiting a file!" name)
      (let ((new-name (read-file-name "New name: " filename)))
        (if (get-buffer new-name)
            (error "A buffer named '%s' already exists!" new-name)
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil)
          (message "File '%s' successfully renamed to '%s'"
                   name (file-name-nondirectory new-name)))))))

(global-set-key (kbd "C-x C-r") #'rename-current-buffer-file)

(global-set-key (kbd "C-0") #'delete-window)
(global-set-key (kbd "C-1") #'delete-other-windows)
(global-set-key (kbd "C-2") #'split-window-below)
(global-set-key (kbd "C-3") #'split-window-right)
(global-set-key (kbd "C-4") #'find-file-other-window)
(global-set-key (kbd "C-5") #'make-frame-command)
(global-set-key (kbd "M-j") #'evil-join)
(global-set-key (kbd "C-.") #'er/expand-region)

(define-key key-translation-map (kbd "<mouse-21>") (kbd "<C-mouse-5>"))
(define-key key-translation-map (kbd "<mouse-20>") (kbd "<C-mouse-4>"))
(global-set-key (kbd "<C-mouse-5>") #'evil-scroll-page-down)
(global-set-key (kbd "<C-mouse-4>") #'evil-scroll-page-up)

(use-package subword
  :ensure t
  :diminish subword-mode
  :init (global-subword-mode +1))

(provide 'config-ui)
