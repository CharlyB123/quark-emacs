;; -*- lexical-binding: t -*-
(eval-when-compile (require 'config-macros))

(eval-when-compile
  (with-demoted-errors "Load error: %s"
    (require 'tramp)))

(defvar my/tramp-backup-directory
  (locate-user-emacs-file "data/tramp-backups/"))

(with-eval-after-load 'password-cache
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'password-cache)))
  ;; cache passwords for the duration of the session
  ;; note that said cache is _not_ persistent
  (setq password-cache-expiry nil))

(with-eval-after-load 'tramp-cache
  (eval-when-compile (require 'tramp-cache))
  (setq tramp-persistency-file-name
        (locate-user-emacs-file "data/tramp")))

(with-eval-after-load 'tramp
  (eval-when-compile (require 'tramp))
  (setq tramp-backup-directory-alist `((,(rx (zero-or-more not-newline))
                                        . ,my/tramp-backup-directory))))

;; =================================
;; automatically request root access
;; =================================
(defun my/root-file-name-p (file-name)
  (and (featurep 'tramp)
       (tramp-tramp-file-p file-name)
       (with-parsed-tramp-file-name file-name parsed
         (when parsed-user
           (string= "root" (substring-no-properties parsed-user))))))

(defun my/tramp-get-method-parameter (method param)
  (assoc param (assoc method tramp-methods)))

(defun my/tramp-corresponding-inline-method (method)
  (let* ((login-program
          (my/tramp-get-method-parameter method 'tramp-login-program))
         (login-args
          (my/tramp-get-method-parameter method 'tramp-login-args))
         (copy-program
          (my/tramp-get-method-parameter method 'tramp-copy-program)))
    (or
     ;; If the method is already inline, it's already okay
     (and login-program
          (not copy-program)
          method)

     ;; If the method isn't inline, try calculating the corresponding
     ;; inline method, by matching other properties.
     (and copy-program
          (cl-some
           (lambda (test-method)
             (when (and
                    (equal login-args
                           (my/tramp-get-method-parameter
                            test-method
                            'tramp-login-args))
                    (equal login-program
                           (my/tramp-get-method-parameter
                            test-method
                            'tramp-login-program))
                    (not (my/tramp-get-method-parameter
                          test-method
                          'tramp-copy-program)))
               test-method))
           (mapcar #'car tramp-methods)))

     ;; These methods are weird and need to be handled specially
     (and (member method '("sftp" "fcp"))
          "sshx"))))

(defun my/make-root-file-name (file-name &optional user)
  (require 'tramp)
  (let* ((target-user (or user "root"))
         (abs-file-name (expand-file-name file-name))
         (sudo (with-demoted-errors "sudo check failed: %s"
                 (let ((default-directory
                         (my/file-name-first-existing-parent abs-file-name))
                       (process-file-side-effects nil))
                   (or (= (process-file "sudo" nil nil nil "-n" "true") 0)
                       ;; Detect if sudo can be run with a password
                       (string-match-p
                        (rx (or "askpass" "password"))
                        (with-output-to-string
                          (with-current-buffer standard-output
                            (process-file "sudo" nil t nil "-vS")))))))))
    (if (tramp-tramp-file-p abs-file-name)
        (with-parsed-tramp-file-name abs-file-name parsed
          (if (string= parsed-user target-user)
              abs-file-name
            (tramp-make-tramp-file-name
             (if sudo "sudo" "su")
             target-user
             nil
             parsed-host
             nil
             parsed-localname
             (let ((tramp-postfix-host-format tramp-postfix-hop-format)
                   (tramp-prefix-format))
               (tramp-make-tramp-file-name
                (my/tramp-corresponding-inline-method parsed-method)
                parsed-user
                parsed-domain
                parsed-host
                parsed-port
                ""
                parsed-hop)))))
      (if (string= (user-login-name) user)
          abs-file-name
        (tramp-make-tramp-file-name (if sudo "sudo" "su")
                                    target-user
                                    nil
                                    "localhost"
                                    nil
                                    abs-file-name)))))

(defun edit-file-as-root ()
  "Find file as root"
  (interactive)
  (find-alternate-file (my/make-root-file-name buffer-file-name)))

(add-hook
 'find-file-hook
 (my/defun-as-value my/edit-file-as-root-maybe ()
   "Find file as root if necessary."
   (when (and buffer-file-name
              (not (file-writable-p buffer-file-name))
              (not (string= user-login-name
                            (nth 3 (file-attributes buffer-file-name 'string))))
              (not (my/root-file-name-p buffer-file-name)))
     (setq buffer-read-only nil)
     (add-hook 'first-change-hook #'root-save-mode nil t)
     (run-with-idle-timer
      0.5 nil
      (lambda ()
        (message "Modifications will require root permissions to save."))))))

;; also fallback to root if file cannot be read
(advice-add
 'find-file-noselect-1 :around
 (my/defun-as-value nadvice/find-file-noselect-1 (old-fun buf filename &rest args)
   (condition-case err
       (apply old-fun buf filename args)
     (file-error
      (if (and (not (my/root-file-name-p filename))
               (y-or-n-p "File is not readable. Open with root? "))
          (let ((filename (my/make-root-file-name (file-truename filename))))
            (apply #'find-file-noselect-1
                   (or (get-file-buffer filename)
                       (create-file-buffer filename))
                   filename
                   args))
        (signal (car err) (cdr err)))))))

(defun nadvice/make-directory/auto-root (old-fun &rest args)
  (cl-letf*
      ((old-md (symbol-function #'make-directory))
       ((symbol-function #'make-directory)
        (lambda (dir &optional parents)
          (if (and (not (my/root-file-name-p dir))
                   (not (file-writable-p
                         (my/file-name-first-existing-parent dir)))
                   (y-or-n-p "Insufficient permissions. Create with root? "))
              (funcall old-md
                       (my/make-root-file-name dir)
                       parents)
            (funcall old-md dir parents)))))
    (apply old-fun args)))

(advice-add 'basic-save-buffer :around #'nadvice/make-directory/auto-root)

(with-eval-after-load 'helm-files
  (eval-when-compile
    (with-demoted-errors "Load error: %s"
      (require 'helm-files)))
  (advice-add 'helm-find-file-or-marked :around
              #'nadvice/make-directory/auto-root))

(advice-add
 'semantic-find-file-noselect :around
 (my/defun-as-value nadvice/semantic-find-file-noselect/supress-find-file-hook (old-fun &rest args)
   (cl-letf* ((old-aff (symbol-function #'after-find-file))
              ((symbol-function #'after-find-file)
               (lambda (&rest args)
                 (let ((find-file-hook))
                   (apply old-aff args)))))
     (apply old-fun args))))

(defvar root-save-mode-lighter
  (list " " (propertize "root" 'face 'tty-menu-selected-face))
  "The mode line lighter for root-save-mode.")

;; Required for the face to be displayed
(put 'root-save-mode-lighter 'risky-local-variable t)

(defun root-save-mode/before-save ()
  "Switch the visiting file to a TRAMP su or sudo name if applicable"
  (when (and (buffer-modified-p)
             (not (my/root-file-name-p buffer-file-name))
             (or (not (= (process-file "sudo" nil nil nil "-n" "true") 0))
                 (yes-or-no-p "File is not writable. Save with root? ")))
    (let ((change-major-mode-with-file-name nil))
      (set-visited-file-name (my/make-root-file-name buffer-file-name) t t))
    (remove-hook 'before-save-hook #'root-save-mode/before-save t)))

(advice-add
 'find-file-noselect :around
 (my/defun-as-value nadvice/find-file-noselect (old-fun &rest args)
   (cl-letf* ((old-fwp (symbol-function #'file-writable-p))
              ((symbol-function #'file-writable-p)
               (lambda (&rest iargs)
                 (or (member 'root-save-mode first-change-hook)
                     (bound-and-true-p root-save-mode)
                     (apply old-fwp iargs)))))
     (apply old-fun args))))

(define-minor-mode root-save-mode
  "Automatically save buffer as root"
  :lighter root-save-mode-lighter
  (if root-save-mode
      ;; Ensure that root-save-mode is visible by promoting it to rank 1
      (progn
        (let ((root-save-mode-alist-entry
               (assoc 'root-save-mode minor-mode-alist)))
          (setq minor-mode-alist
                (delete root-save-mode-alist-entry minor-mode-alist))
          (push root-save-mode-alist-entry minor-mode-alist))
        (add-hook 'before-save-hook #'root-save-mode/before-save nil t))
    (remove-hook 'before-save-hook #'root-save-mode/before-save t)))

(provide 'config-tramp)
