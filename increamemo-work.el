;;; increamemo-work.el --- Work session runtime for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Work session runtime and minor mode state.

;;; Code:

(require 'cl-lib)
(require 'increamemo-config)
(require 'increamemo-domain)
(require 'increamemo-opener)
(require 'increamemo-time)

(cl-defstruct increamemo-session
  id
  date
  handled-count
  excluded-item-ids
  current-item-id
  active-p)

(defvar increamemo-work--session nil
  "The active increamemo work session.")

(defvar increamemo-work--next-session-id 0
  "Monotonic identifier source for work sessions.")

(defvar-local increamemo-work--current-item-id nil
  "The current item id in the work buffer.")

(defvar-local increamemo-work--session-id nil
  "The owning session id for the current work buffer.")

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
  :lighter (:eval (increamemo-work--mode-line-text))
  :keymap increamemo-work-mode-map)

(defun increamemo-work--remaining-count ()
  "Return the remaining due item count for the active session."
  (if (and increamemo-work--session
           (increamemo-session-active-p increamemo-work--session))
      (length
       (increamemo-domain-list-due
        (increamemo-session-date increamemo-work--session)
        (increamemo-session-excluded-item-ids increamemo-work--session)))
    0))

(defun increamemo-work--mode-line-text ()
  "Return the mode line text for the active session."
  (if (and increamemo-work-mode
           increamemo-work--session
           (increamemo-session-active-p increamemo-work--session))
      (funcall increamemo-mode-line-format-function
               (increamemo-session-handled-count increamemo-work--session)
               (increamemo-work--remaining-count))
    ""))

(defun increamemo-work--clear-buffer-state ()
  "Clear work session state from the current buffer."
  (setq increamemo-work--current-item-id nil)
  (setq increamemo-work--session-id nil))

(defun increamemo-work--activate-buffer (buffer item)
  "Enable work mode in BUFFER for ITEM."
  (with-current-buffer buffer
    (setq-local increamemo-work--current-item-id (plist-get item :id))
    (setq-local increamemo-work--session-id
                (increamemo-session-id increamemo-work--session))
    (increamemo-work-mode 1))
  buffer)

(defun increamemo-work-start ()
  "Start a work session."
  (let* ((today (increamemo-time-today))
         (session
          (make-increamemo-session
           :id (cl-incf increamemo-work--next-session-id)
           :date today
           :handled-count 0
           :excluded-item-ids nil
           :current-item-id nil
           :active-p t))
         (items nil))
    (setq increamemo-work--session session)
    (setq items
          (increamemo-domain-list-due
           today
           (increamemo-session-excluded-item-ids session)))
    (if (null items)
        (progn
          (setq increamemo-work--session nil)
          (message "Increamemo: no due items")
          nil)
      (let* ((item (car items))
             (buffer (increamemo-opener-open-item item)))
        (setf (increamemo-session-current-item-id increamemo-work--session)
              (plist-get item :id))
        (increamemo-work--activate-buffer buffer item)))))

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
  (when (and increamemo-work--session
             (equal increamemo-work--session-id
                    (increamemo-session-id increamemo-work--session)))
    (setq increamemo-work--session nil))
  (increamemo-work--clear-buffer-state)
  (increamemo-work-mode -1))

(declare-function increamemo-board "increamemo")

(provide 'increamemo-work)
;;; increamemo-work.el ends here
