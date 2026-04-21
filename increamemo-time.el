;;; increamemo-time.el --- Time helpers for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers for current date and timestamp formatting.

;;; Code:

(defun increamemo-time-today (&optional time-value)
  "Return TIME-VALUE as an ISO date, or today's date when omitted."
  (format-time-string "%F" time-value))

(defun increamemo-time-now (&optional time-value)
  "Return TIME-VALUE as an ISO 8601 timestamp, or the current time when omitted."
  (format-time-string "%FT%T%:z" time-value))

(provide 'increamemo-time)
;;; increamemo-time.el ends here
