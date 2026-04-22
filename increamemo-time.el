;;; increamemo-time.el --- Time helpers for increamemo  -*- lexical-binding: t; -*-

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

;; Helpers for current date and timestamp formatting.

;;; Code:

(require 'calendar)

(defconst increamemo-time--date-regexp
  "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
  "Regexp used to validate ISO date strings.")

(defun increamemo-time--parse-date (value)
  "Return VALUE as a Gregorian date list, or nil when invalid."
  (when (and (stringp value)
             (string-match-p increamemo-time--date-regexp value))
    (let* ((year (string-to-number (substring value 0 4)))
           (month (string-to-number (substring value 5 7)))
           (day (string-to-number (substring value 8 10))))
      (when (and (<= 1 month)
                 (<= month 12)
                 (<= 1 day)
                 (<= day (calendar-last-day-of-month month year)))
        (list month day year)))))

(defun increamemo-time--format-date (gregorian-date)
  "Return GREGORIAN-DATE formatted as an ISO date string."
  (pcase-let ((`(,month ,day ,year) gregorian-date))
    (format "%04d-%02d-%02d" year month day)))

(defun increamemo-time-valid-date-p (value)
  "Return non-nil when VALUE is a valid ISO date string."
  (and (increamemo-time--parse-date value) t))

(defun increamemo-time-add-days (date days)
  "Return DATE plus DAYS as an ISO date string."
  (let ((gregorian-date (increamemo-time--parse-date date)))
    (unless gregorian-date
      (user-error "Increamemo: invalid due date: %S" date))
    (unless (integerp days)
      (user-error "Increamemo: invalid day offset: %S" days))
    (increamemo-time--format-date
     (calendar-gregorian-from-absolute
      (+ (calendar-absolute-from-gregorian gregorian-date)
         days)))))

(defun increamemo-time-today (&optional time-value)
  "Return TIME-VALUE as an ISO date, or today's date when omitted."
  (format-time-string "%F" time-value))

(defun increamemo-time-now (&optional time-value)
  "Return TIME-VALUE as an ISO 8601 timestamp, or the current time when omitted."
  (format-time-string "%FT%T%:z" time-value))

(provide 'increamemo-time)
;;; increamemo-time.el ends here
