;;; increamemo-policy.el --- Policy adapters for increamemo  -*- lexical-binding: t; -*-

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

;; Rescheduling policy adapter and default scheduling policy.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-time)

(defun increamemo-default-reschedule (item action)
  "Return the next due date for ITEM after ACTION.

The default policy schedules the next review for the following day."
  (ignore action)
  (let ((base-date (or (plist-get item :next-due-date)
                       (increamemo-time-today))))
    (increamemo-time-add-days base-date 1)))

(defun increamemo-policy--invoke-reschedule-function
    (item action history-summary today)
  "Call `increamemo-reschedule-function' with supported context.

Functions may accept either `(ITEM ACTION)' or
`(ITEM ACTION HISTORY-SUMMARY TODAY)'."
  (let* ((arity (func-arity increamemo-reschedule-function))
         (minimum (car arity))
         (maximum (cdr arity))
         (supports-four
          (or (eq maximum 'many)
              (>= maximum 4)))
         (supports-two
          (and (not (eq maximum 'many))
               (<= minimum 2)
               (>= maximum 2))))
    (cond
     (supports-four
      (funcall increamemo-reschedule-function
               item
               action
               history-summary
               today))
     (supports-two
      (funcall increamemo-reschedule-function item action))
     (t
      (user-error
       (concat
        "Increamemo: `increamemo-reschedule-function' must accept "
        "2 or 4 arguments"))))))

(defun increamemo-policy-compute-next-due-date
    (item action history-summary today)
  "Return the validated next due date for ITEM after ACTION.

HISTORY-SUMMARY and TODAY are accepted to keep the adapter contract stable."
  (let ((candidate
         (increamemo-policy--invoke-reschedule-function
          item action history-summary today)))
    (unless (increamemo-time-valid-date-p candidate)
      (user-error "Increamemo: invalid reschedule date: %S" candidate))
    candidate))

(provide 'increamemo-policy)
;;; increamemo-policy.el ends here
