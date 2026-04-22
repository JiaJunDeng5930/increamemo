;;; increamemo-config-time-test.el --- Config and time tests  -*- lexical-binding: t; -*-

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
        (increamemo-initial-due-date-function #'ignore)
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
            :initial-due-date-function #'ignore
            :reschedule-function #'ignore
            :mode-line-format-function
            #'increamemo-default-mode-line-format
            :backends '(increamemo-file-backend
                        increamemo-ekg-backend))))))

(ert-deftest increamemo-config-require-ready-rejects-invalid-policy ()
  "Readiness checks reject unknown invalid opener policies."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-invalid-opener-policy 'drop))
    (should
     (equal
      (condition-case err
          (progn
            (increamemo-config-require-ready)
            nil)
        (user-error (cadr err)))
      "Increamemo: invalid opener policy: drop"))))

(ert-deftest increamemo-config-require-ready-rejects-directory-path ()
  "Readiness checks reject directory paths for the database file."
  (let ((temp-dir (make-temp-file "increamemo-config-dir-" t)))
    (unwind-protect
        (let ((increamemo-db-file temp-dir))
          (should-error (increamemo-config-require-ready) :type 'user-error))
      (delete-directory temp-dir t))))

(ert-deftest increamemo-config-require-ready-rejects-directory-syntax-path ()
  "Readiness checks reject paths that syntactically name a directory."
  (let ((increamemo-db-file "/tmp/increamemo-directory/"))
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

(ert-deftest increamemo-config-require-ready-rejects-invalid-initial-due-function ()
  "Readiness checks reject non-callable initial due date functions."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-initial-due-date-function 'not-a-function))
    (should-error (increamemo-config-require-ready) :type 'user-error)))

(ert-deftest increamemo-config-require-ready-rejects-invalid-backend-list ()
  "Readiness checks reject backend lists with non-symbol entries."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-backends '(increamemo-file-backend "ekg")))
    (should-error (increamemo-config-require-ready) :type 'user-error)))

(ert-deftest increamemo-config-require-ready-rejects-nil-backend-entry ()
  "Readiness checks reject backend lists containing nil."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-backends '(increamemo-file-backend nil)))
    (should-error (increamemo-config-require-ready) :type 'user-error)))

(ert-deftest increamemo-config-require-ready-rejects-improper-backend-list ()
  "Readiness checks reject improper backend lists."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite")
        (increamemo-backends '(increamemo-file-backend . increamemo-ekg-backend)))
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
