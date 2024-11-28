;;; msh.el --- Meta shell mode -*- lexical-binding: t -*-

;; Author: Laluxx
;; Keywords: processes, terminals
;; Package-Version: 1.2.0
;; Package-Requires: ((emacs "27.1") (corfu "0.34"))

;;; Commentary:
;; Meta Shell (MSH) is a ZSH shell mode built on top of comint-mode.
;; Edit ~/.config/emacs/msh/.zshrc to configure the shell.
;; I wrote this to have a fast minimal shell mode for emacs.
;; With it's separate config file.

;;; Code:

(require 'comint)
(require 'shell)
(require 'corfu)

(defgroup msh nil
  "MSH mode for ZSH integration."
  :group 'shells)

(defcustom msh-window-height 0.3
  "Height of the MSH window as a fraction of the frame height."
  :type 'float
  :group 'msh)

(defcustom msh-config-directory (expand-file-name "msh" user-emacs-directory)
  "Directory for MSH configuration files."
  :type 'directory
  :group 'msh)

(defcustom msh-config-file (expand-file-name ".zshrc" msh-config-directory)
  "Path to MSH configuration file."
  :type 'file
  :group 'msh)

(defcustom msh-auto-edit-config t
  "If non-nil, automatically open config file when it doesn't exist."
  :type 'boolean
  :group 'msh)

(defcustom msh-zsh-program "/bin/zsh"
  "Location of ZSH executable."
  :type 'file
  :group 'msh)

(defvar msh-buffer-name "*msh*"
  "Name of the MSH buffer.")

(defvar msh-prompt-pattern "^[^#$%>\n]*[#$%>] *"
  "Regexp to match ZSH prompt.")

(defface msh-prompt-face
  '((t (:foreground "green" :weight bold)))
  "Face for MSH prompt."
  :group 'msh)

(defface msh-output-face
  '((t (:foreground "cyan")))
  "Face for MSH output."
  :group 'msh)

(defvar msh-font-lock-keywords
  '(("\\<\\(if\\|else\\|elif\\|fi\\|for\\|while\\|do\\|done\\|case\\|esac\\|function\\)\\>" . font-lock-keyword-face)
    ("\\<\\(echo\\|exit\\|export\\|cd\\|pwd\\)\\>" . font-lock-builtin-face)
    ("\\$\\w+" . font-lock-variable-name-face)
    ("\\<\\(true\\|false\\)\\>" . font-lock-constant-face))
  "Font lock keywords for MSH mode.")

(defvar msh-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-r") 'msh-reload-config)
    (define-key map (kbd "C-c C-e") 'msh-edit-config)
    (define-key map (kbd "C-l") 'msh-clear-screen)
    (define-key map (kbd "M-p") 'comint-previous-matching-input-from-input)
    (define-key map (kbd "M-n") 'comint-next-matching-input-from-input)
    map)
  "Keymap for MSH major mode.")

(defun msh-clear-screen ()
  "Clear the shell buffer and move point to the bottom."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (comint-send-input)
    (goto-char (point-max))))

(defun msh-get-or-create-window ()
  "Get the MSH window if it exists, or create it."
  (let* ((buffer (get-buffer-create msh-buffer-name))
         (window (get-buffer-window buffer)))
    (if window
        window
      (let ((height (floor (* (frame-height) msh-window-height))))
        (display-buffer-in-side-window
         buffer
         `((side . bottom)
           (slot . -1)
           (window-height . ,height)
           (preserve-size . (nil . t))
           (dedicated . t)))))))

(defun msh-toggle ()
  "Toggle the MSH window at the bottom of the frame."
  (interactive)
  (let* ((buffer (get-buffer-create msh-buffer-name))
         (window (get-buffer-window buffer)))
    (if window
        (delete-window window)
      (let ((new-window (msh-get-or-create-window)))
        (with-selected-window new-window
          (unless (comint-check-proc buffer)
            (msh)))
        (select-window new-window)))))

(defun msh-get-zsh-args ()
  "Get arguments for clean ZSH instance."
  (list
   "-d"                ; Don't run as a login shell
   "-f"                ; Don't load RCS files (same as --no-rcs)
   "--no-globalrcs"    ; Don't load global config files
   "-i"                ; Interactive shell
   "-c"                ; Read commands from string
   (format "ZDOTDIR=%s; source %s; exec zsh -i" 
           msh-config-directory
           msh-config-file)))

(defun msh-load-config ()
  "Load MSH configuration from `msh-config-file'."
  (when (file-exists-p msh-config-file)
    (load-file msh-config-file)))

(defun msh-reload-config ()
  "Reload MSH configuration."
  (interactive)
  (msh-load-config)
  (message "MSH configuration reloaded."))

(defun msh-edit-config ()
  "Open MSH configuration file for editing."
  (interactive)
  (unless (file-exists-p msh-config-directory)
    (make-directory msh-config-directory t))
  (find-file msh-config-file))

(defun msh-initialize-config ()
  "Initialize MSH configuration if it doesn't exist."
  (unless (file-exists-p msh-config-file)
    (unless (file-exists-p msh-config-directory)
      (make-directory msh-config-directory t))
    
    (with-temp-file msh-config-file
      (insert "# MSH ZSH Configuration\n\n")
      (insert "# History Configuration\n")
      (insert "HISTFILE=${HOME}/.cache/emacs/msh/history\n")
      (insert "HISTSIZE=10000\n")
      (insert "SAVEHIST=10000\n")
      (insert "mkdir -p ${HOME}/.cache/emacs/msh\n\n")
      (insert "# Emacs key bindings\n")
      (insert "bindkey -e\n\n")
      (insert "# Shell Options\n")
      (insert "setopt EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS\n")
      (insert "setopt HIST_IGNORE_SPACE HIST_VERIFY HIST_REDUCE_BLANKS\n")
      (insert "setopt INTERACTIVE_COMMENTS AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT\n\n")
      (insert "# Completion System\n")
      (insert "autoload -Uz compinit && compinit\n\n")
      (insert "# Prompt Configuration\n")
      (insert "setopt PROMPT_SUBST\n")
      (insert "autoload -Uz colors && colors\n")
      (insert "PS1='%F{green}%n@%m%f:%F{blue}%~%f%# '\n\n")
      (insert "# Useful Aliases\n")
      (insert "alias ls='ls --color=auto'\n")
      (insert "alias ll='ls -lah'\n")
      (insert "alias grep='grep --color=auto'\n")
      (insert "alias ..='cd ..'\n")
      (insert "alias ...='cd ../..'\n\n"))
    
    (when msh-auto-edit-config
      (msh-edit-config))))

(defun msh-preoutput-filter (output)
  "Filter function for MSH output."
  (propertize output 'font-lock-face 'msh-output-face))

(defun msh-dirtrack-filter (str)
  "Custom filter function for directory tracking."
  (when (string-match "\\`\\(?:cd\\|pushd\\|popd\\) \\(.*\\)" str)
    (let ((dir (match-string 1 str)))
      (unless (string-empty-p dir)
        (cd-absolute dir))))
  str)

(defun msh-handle-error (process output)
  "Handle errors in the MSH process."
  (when (string-match "\\(.*\\): command not found" output)
    (message "MSH: Command not found: %s" (match-string 1 output))))

(defun msh-set-env (var value)
  "Set an environment variable in the MSH session."
  (interactive "sVariable: \nsValue: ")
  (comint-send-string (get-buffer-process msh-buffer-name)
                      (format "export %s=%s\n" var value)))

(defun msh-completion-at-point ()
  "Completion at point function for MSH mode."
  (let* ((pos (point))
         (beg (save-excursion
                (skip-chars-backward "^ \t\n")
                (point)))
         (end pos)
         (prefix (buffer-substring-no-properties beg end))
         (process (get-buffer-process (current-buffer)))
         (completions (when process
                        (with-temp-buffer
                          (call-process msh-zsh-program nil t nil "-c"
                                        (format "compgen -A function -A variable -A alias -A command %s" prefix))
                          (split-string (buffer-string) "\n" t)))))
    (list beg end completions)))

;;;###autoload
(define-derived-mode msh-mode comint-mode "MSH"
  "Major mode for interacting with ZSH.
Special commands:
\\{msh-mode-map}"
  (setq comint-prompt-regexp msh-prompt-pattern)
  (setq comint-process-echoes t)
  (setq comint-input-ignoredups t)
  (setq-local comint-program-name msh-zsh-program)
  
  (msh-load-config)
  
  (setq-local comint-prompt-read-only t)
  (setq-local comint-output-filter-functions
              '(ansi-color-process-output
                comint-postoutput-scroll-to-bottom
                msh-handle-error))
  (add-hook 'comint-preoutput-filter-functions 'msh-preoutput-filter nil t)
  (add-hook 'comint-preoutput-filter-functions 'msh-dirtrack-filter nil t)
  
  (font-lock-add-keywords nil msh-font-lock-keywords)
  
  (add-hook 'completion-at-point-functions #'msh-completion-at-point nil t)
  (corfu-mode)
  
  (setq mode-line-format nil))

;;;###autoload
(defun msh ()
  "Run an inferior instance of `zsh' inside Emacs, using msh-mode."
  (interactive)
  (let* ((buffer (get-buffer-create msh-buffer-name))
         (window (get-buffer-window buffer)))
    (msh-initialize-config)
    
    (unless window
      (setq window (msh-get-or-create-window)))
    
    (with-selected-window window
      (unless (comint-check-proc buffer)
        (apply 'make-comint-in-buffer "msh" buffer
               msh-zsh-program nil
               (msh-get-zsh-args))
        (msh-mode)))
    
    buffer))

(provide 'msh)
;;; msh.el ends here
