;;; increamemo-work.el --- Work session runtime for increamemo  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jiajun Deng

;; Author: Jiajun Deng <3230105930@zju.edu.cn>
;; Maintainer: Jiajun Deng <3230105930@zju.edu.cn>

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Work session runtime and minor mode state.

;;; Code:

(require 'cl-lib)
(require 'increamemo-config)
(require 'increamemo-domain)
(require 'increamemo-failure)
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

(defconst increamemo-work--day-offset-regexp
  "\\`\\+?\\([0-9]+\\)\\'"
  "Regexp used for defer prompts that specify a day offset.")

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

(defconst increamemo-work--priority-prompt
  "Priority (0-100): "
  "Prompt used for priority input.")

(defconst increamemo-work--defer-prompt
  "Defer to date (YYYY-MM-DD) or +days: "
  "Prompt used for defer input.")

(define-minor-mode increamemo-work-mode
  "Minor mode for increamemo work sessions."
  :lighter (:eval (increamemo-work--mode-line-text))
  :keymap increamemo-work-mode-map)

(defun increamemo-work--today ()
  "Return the current date for due-item decisions."
  (increamemo-time-today))

(defun increamemo-work--remaining-count ()
  "Return the remaining due item count for the active session."
  (if (and increamemo-work--session
           (increamemo-session-active-p increamemo-work--session))
      (length
       (increamemo-domain-list-due
        (increamemo-work--today)
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

(defun increamemo-work--require-current-item-id ()
  "Return the current work item id or raise `user-error'."
  (unless (and increamemo-work--session
               increamemo-work--current-item-id)
    (user-error "Increamemo: no active work item"))
  increamemo-work--current-item-id)

(defun increamemo-work--mark-current-handled ()
  "Increment the handled count for the active session."
  (setf (increamemo-session-handled-count increamemo-work--session)
        (1+ (increamemo-session-handled-count increamemo-work--session))))

(defun increamemo-work--deactivate-current-buffer ()
  "Disable work mode and clear local state in the current buffer."
  (increamemo-work-mode -1)
  (increamemo-work--clear-buffer-state))

(defun increamemo-work--parse-defer-date (input base-date)
  "Return a due date parsed from INPUT using BASE-DATE.

INPUT accepts either an ISO date or a positive day offset."
  (cond
   ((increamemo-time-valid-date-p input)
    input)
   ((string-match increamemo-work--day-offset-regexp input)
    (increamemo-time-add-days
     base-date
     (string-to-number (match-string 1 input))))
   (t
    (user-error "Increamemo: invalid defer input: %S" input))))

(defun increamemo-work--activate-buffer (buffer item)
  "Enable work mode in BUFFER for ITEM."
  (setf (increamemo-session-current-item-id increamemo-work--session)
        (plist-get item :id))
  (with-current-buffer buffer
    (setq-local increamemo-work--current-item-id (plist-get item :id))
    (setq-local increamemo-work--session-id
                (increamemo-session-id increamemo-work--session))
    (increamemo-work-mode 1))
  buffer)

(defun increamemo-work--open-next-item ()
  "Open the next due item for the active session."
  (let ((items
         (increamemo-domain-list-due
          (increamemo-work--today)
          (increamemo-session-excluded-item-ids increamemo-work--session))))
    (if (null items)
        (progn
          (setq increamemo-work--session nil)
          (message "Increamemo: no due items")
          nil)
      (let ((item (car items)))
        (condition-case err
            (increamemo-work--activate-buffer
             (increamemo-opener-open-item item)
             item)
          (increamemo-opener-error
           (message
            "Increamemo: failed to open item #%s: %s"
            (plist-get item :id)
            (plist-get (car (cdr err)) :message))
           (setf (increamemo-session-handled-count increamemo-work--session)
                 (1+ (increamemo-session-handled-count increamemo-work--session)))
           (increamemo-failure-handle-open-error
            item
            err
            (increamemo-time-now))
           (increamemo-work--open-next-item)))))))

(defun increamemo-work-start ()
  "Start a work session."
  (increamemo-config-require-ready)
  (let* ((today (increamemo-time-today))
         (session
          (make-increamemo-session
           :id (cl-incf increamemo-work--next-session-id)
           :date today
           :handled-count 0
           :excluded-item-ids nil
           :current-item-id nil
           :active-p t)))
    (setq increamemo-work--session session)
    (increamemo-work--open-next-item)))

(defun increamemo-work-complete ()
  "Complete the current item."
  (interactive)
  (increamemo-config-require-ready)
  (let* ((item-id (increamemo-work--require-current-item-id))
         (result
          (increamemo-domain-complete-current
           item-id
           (increamemo-work--today)
           (increamemo-time-now)))
         (status (plist-get result :status)))
    (when (eq status 'completed)
      (increamemo-work--mark-current-handled))
    (increamemo-work--deactivate-current-buffer)
    (increamemo-work--open-next-item)))

(defun increamemo-work-archive ()
  "Archive the current item."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-domain-archive-item
   (increamemo-work--require-current-item-id)
   (increamemo-time-now))
  (increamemo-work--mark-current-handled)
  (increamemo-work--deactivate-current-buffer)
  (increamemo-work--open-next-item))

(defun increamemo-work-defer ()
  "Defer the current item."
  (interactive)
  (increamemo-config-require-ready)
  (let* ((item-id (increamemo-work--require-current-item-id))
         (raw-input (read-string increamemo-work--defer-prompt))
         (new-due-date
          (increamemo-work--parse-defer-date
           raw-input
           (increamemo-work--today))))
    (increamemo-domain-defer-item item-id new-due-date (increamemo-time-now))
    (increamemo-work--mark-current-handled)
    (increamemo-work--deactivate-current-buffer)
    (increamemo-work--open-next-item)))

(defun increamemo-work-skip ()
  "Skip the current item."
  (interactive)
  (increamemo-config-require-ready)
  (let ((item-id (increamemo-work--require-current-item-id)))
    (increamemo-domain-skip-item item-id (increamemo-time-now))
    (cl-pushnew item-id
                (increamemo-session-excluded-item-ids increamemo-work--session))
    (increamemo-work--mark-current-handled)
    (increamemo-work--deactivate-current-buffer)
    (increamemo-work--open-next-item)))

(defun increamemo-work-update-priority ()
  "Adjust the current item priority."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-domain-update-priority
   (increamemo-work--require-current-item-id)
   (read-number increamemo-work--priority-prompt)
   (increamemo-time-now))
  (force-mode-line-update t))

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
