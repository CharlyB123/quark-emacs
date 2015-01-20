(eval-when-compile
  (with-demoted-errors
    (require 'company)))

(global-company-mode +1)

(with-eval-after-load 'company
  (diminish 'company-mode (if (display-graphic-p) " γ" " Co"))
  (setq
    company-idle-delay 0.1
    company-echo-delay 0
    company-auto-complete 'company-explicit-action-p
    company-minimum-prefix-length 2
    company-show-numbers nil
    company-tooltip-align-annotations t)

  (defun company-complete-common-or-complete-full ()
    (interactive)
    (when (company-manual-begin)
      (if (eq last-command #'company-complete-common-or-cycle)
        (let ((company-selection-wrap-around t))
          (call-interactively #'company-complete-selection))
        (let ((buffer-mod-tick (buffer-chars-modified-tick)))
          (call-interactively #'company-complete-common)
          (when (= buffer-mod-tick (buffer-chars-modified-tick))
            (call-interactively #'company-complete-selection)
            (call-interactively #'company-complete))))))

  (define-key company-active-map [tab] #'company-complete-common-or-complete-full)
  (define-key company-active-map (kbd "TAB") #'company-complete-common-or-complete-full)

  (set-face-background 'company-tooltip-common-selection
    (face-background 'company-tooltip-selection))
  (set-face-background 'company-tooltip-common
    (face-background 'company-tooltip)))

(provide 'config-auto-complete)
