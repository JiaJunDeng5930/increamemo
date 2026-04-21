;;; increamemo-work.el --- Work session runtime for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Work mode boundary and placeholders.

;;; Code:

(defvar increamemo-work-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c , c") #'increamemo-work-complete)
    (define-key map (kbd "C-c , a") #'increamemo-work-archive)
    (define-key map (kbd "C-c , d") #'increamemo-work-defer)
    (define-key map (kbd "C-c , s") #'increamemo-work-skip)
    (define-key map (kbd "C-c , p") #'increamemo-work-update-priority)
    (define-key map (kbd "C-c , q") #'increamemo-work-quit)
    (define-key map (kbd "C-c , b") #'increamemo-board)
    map)
  "Keymap for `increamemo-work-mode'.")

(define-minor-mode increamemo-work-mode
  "Minor mode for increamemo work sessions."
  :lighter " IM"
  :keymap increamemo-work-mode-map)

(defun increamemo-work-start ()
  "Start a work session."
  (user-error "Increamemo: work is not implemented yet"))

(defun increamemo-work-complete ()
  "Complete the current item."
  (interactive)
  (user-error "Increamemo: complete is not implemented yet"))

(defun increamemo-work-archive ()
  "Archive the current item."
  (interactive)
  (user-error "Increamemo: archive is not implemented yet"))

(defun increamemo-work-defer ()
  "Defer the current item."
  (interactive)
  (user-error "Increamemo: defer is not implemented yet"))

(defun increamemo-work-skip ()
  "Skip the current item."
  (interactive)
  (user-error "Increamemo: skip is not implemented yet"))

(defun increamemo-work-update-priority ()
  "Adjust the current item priority."
  (interactive)
  (user-error "Increamemo: priority update is not implemented yet"))

(defun increamemo-work-quit ()
  "Quit the current work session."
  (interactive)
  (increamemo-work-mode -1))

(declare-function increamemo-board "increamemo")

(provide 'increamemo-work)
;;; increamemo-work.el ends here
