;;; increamemo-time.el --- Time helpers for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers for current date and timestamp formatting.

;;; Code:

(defun increamemo-time-today ()
  "Return today's date in ISO format."
  (format-time-string "%F"))

(defun increamemo-time-now ()
  "Return the current timestamp in ISO 8601 format."
  (format-time-string "%FT%T%z"))

(provide 'increamemo-time)
;;; increamemo-time.el ends here
