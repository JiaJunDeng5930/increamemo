;;; increamemo-opener-test.el --- Opener tests  -*- lexical-binding: t; -*-

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

;; Regression tests for item opening side effects.

;;; Code:

(require 'ert)
(require 'increamemo-opener)
(require 'increamemo-test-support)

(defun increamemo-opener-test--item (locator opener)
  "Return a file item plist for LOCATOR and OPENER."
  (list :id 42
        :type "file"
        :locator locator
        :opener opener))

(ert-deftest increamemo-opener-opens-file-item-with-resolved-opener ()
  "Opening a file item returns the opened buffer."
  (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
    (let ((opened-buffer
           (increamemo-opener-open-item
            (increamemo-opener-test--item
             (expand-file-name buffer-file-name)
             "find-file"))))
      (unwind-protect
          (should (equal (buffer-file-name opened-buffer)
                         (expand-file-name buffer-file-name)))
        (when (buffer-live-p opened-buffer)
          (kill-buffer opened-buffer))))))

(ert-deftest increamemo-opener-rejects-unresolved-opener ()
  "Opening fails when the opener symbol cannot be resolved."
  (should-error
   (increamemo-opener-open-item
    (increamemo-opener-test--item "/tmp/topic.md" "missing-opener"))
   :type 'increamemo-opener-error))

(ert-deftest increamemo-opener-rejects-missing-file-before-opening ()
  "Opening fails when the file locator does not exist."
  (should-error
   (increamemo-opener-open-item
    (increamemo-opener-test--item "/tmp/increamemo-missing-file.md" "find-file"))
   :type 'increamemo-opener-error))

(ert-deftest increamemo-opener-wraps-opener-execution-errors ()
  "Opening fails with a classified opener error when the opener raises."
  (cl-letf (((symbol-function 'increamemo-opener-test-broken-opener)
             (lambda (&rest _args)
               (error "broken opener"))))
    (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
      (should-error
       (increamemo-opener-open-item
        (increamemo-opener-test--item
         (expand-file-name buffer-file-name)
         "increamemo-opener-test-broken-opener"))
       :type 'increamemo-opener-error))))

(provide 'increamemo-opener-test)
;;; increamemo-opener-test.el ends here
