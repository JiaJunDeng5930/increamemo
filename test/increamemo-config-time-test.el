;;; increamemo-config-time-test.el --- Config and time tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for configuration and time helpers.

;;; Code:

(require 'ert)
(require 'increamemo-config)
(require 'increamemo-time)

(defmacro increamemo-test-with-time-zone (zone &rest body)
  "Run BODY with the process time zone set to ZONE."
  (declare (indent 1) (debug (form body)))
  `(let ((original-zone (getenv "TZ")))
     (unwind-protect
         (progn
           (setenv "TZ" ,zone)
           (set-time-zone-rule ,zone)
           ,@body)
       (setenv "TZ" original-zone)
       (set-time-zone-rule original-zone))))

(ert-deftest increamemo-config-require-ready-expands-path-and-returns-snapshot ()
  "Ready configuration returns an expanded snapshot."
  (let ((increamemo-db-file "~/tmp/increamemo.sqlite")
        (increamemo-invalid-opener-policy 'archive)
        (increamemo-reschedule-function #'ignore)
        (increamemo-mode-line-format-function
         #'increamemo-default-mode-line-format)
        (increamemo-backends '(increamemo-file-backend
                               increamemo-ekg-backend)))
    (should
     (equal
      (increamemo-config-require-ready)
      (list :db-file (expand-file-name increamemo-db-file)
            :invalid-opener-policy 'archive
            :reschedule-function #'ignore
            :mode-line-format-function
            #'increamemo-default-mode-line-format
            :backends '(increamemo-file-backend
                        increamemo-ekg-backend))))))

(ert-deftest increamemo-config-require-ready-rejects-invalid-policy ()
  "Readiness checks reject unknown invalid opener policies."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-invalid-opener-policy 'drop))
    (should-error (increamemo-config-require-ready) :type 'user-error)))

(ert-deftest increamemo-config-require-ready-rejects-invalid-mode-line-function ()
  "Readiness checks reject non-callable mode line formatters."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-mode-line-format-function 'not-a-function))
    (should-error (increamemo-config-require-ready) :type 'user-error)))

(ert-deftest increamemo-config-require-ready-rejects-invalid-reschedule-function ()
  "Readiness checks reject non-callable reschedule functions."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-reschedule-function 'not-a-function))
    (should-error (increamemo-config-require-ready) :type 'user-error)))

(ert-deftest increamemo-default-mode-line-format-renders-counts ()
  "The default formatter renders handled and remaining counts."
  (should (equal (increamemo-default-mode-line-format 3 12)
                 "IM[3/12]")))

(ert-deftest increamemo-time-today-formats-iso-date ()
  "The time provider emits ISO dates."
  (increamemo-test-with-time-zone "UTC0"
    (let ((time-value (encode-time 7 8 9 21 4 2026 t)))
      (should (equal (increamemo-time-today time-value)
                     "2026-04-21")))))

(ert-deftest increamemo-time-now-formats-iso-timestamp ()
  "The time provider emits ISO 8601 timestamps."
  (increamemo-test-with-time-zone "UTC0"
    (let ((time-value (encode-time 7 8 9 21 4 2026 t)))
      (should (equal (increamemo-time-now time-value)
                     "2026-04-21T09:08:07+00:00")))))

(provide 'increamemo-config-time-test)
;;; increamemo-config-time-test.el ends here
