;;; increamemo-policy.el --- Policy adapters for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Rescheduling policy adapter and default scheduling policy.

;;; Code:

(require 'increamemo-config)

(defconst increamemo-policy--date-regexp
  "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
  "Regexp used to validate policy-produced ISO dates.")

(defun increamemo-default-reschedule (item action)
  "Return the next due date for ITEM after ACTION.

The default policy schedules the next review for the following day."
  (ignore action)
  (let* ((base-date (or (plist-get item :next-due-date)
                        (format-time-string "%F")))
         (base-time (date-to-time (concat base-date " 00:00:00 +0000"))))
    (format-time-string "%F" (time-add base-time (days-to-time 1)) t)))

(defun increamemo-policy--valid-date-p (value)
  "Return non-nil when VALUE is a valid ISO date string."
  (and (stringp value)
       (string-match-p increamemo-policy--date-regexp value)
       (let* ((year (string-to-number (substring value 0 4)))
              (month (string-to-number (substring value 5 7)))
              (day (string-to-number (substring value 8 10))))
         (condition-case nil
             (string= value
                      (format-time-string
                       "%F"
                       (encode-time 0 0 0 day month year nil)
                       t))
           (error nil)))))

(defun increamemo-policy-compute-next-due-date
    (item action history-summary today)
  "Return the validated next due date for ITEM after ACTION.

HISTORY-SUMMARY and TODAY are accepted to keep the adapter contract stable."
  (ignore history-summary today)
  (let ((candidate (funcall increamemo-reschedule-function item action)))
    (unless (increamemo-policy--valid-date-p candidate)
      (user-error "Increamemo: invalid reschedule date: %S" candidate))
    candidate))

(provide 'increamemo-policy)
;;; increamemo-policy.el ends here
