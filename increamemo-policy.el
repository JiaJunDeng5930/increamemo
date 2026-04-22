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

(defun increamemo-default-reschedule (item action history-summary today)
  "Return the next due date for ITEM after ACTION.

The default policy grows the previous interval from HISTORY-SUMMARY using the
stored multiplier from ITEM and anchors the next due date on TODAY."
  (ignore action)
  (let* ((a-factor (plist-get item :a-factor))
         (previous-interval-days
          (plist-get history-summary :previous-interval-days)))
    (unless (and (numberp a-factor)
                 (>= a-factor 1.0))
      (user-error "Increamemo: invalid item a-factor: %S" a-factor))
    (unless (and (integerp previous-interval-days)
                 (<= 0 previous-interval-days))
      (user-error
       "Increamemo: invalid previous interval: %S"
       previous-interval-days))
    (let* ((grown-interval (ceiling (* previous-interval-days a-factor)))
           (next-interval-days (max grown-interval
                                    (1+ previous-interval-days))))
      (increamemo-time-add-days today next-interval-days))))

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
