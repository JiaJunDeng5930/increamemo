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
(require 'cl-lib)
(require 'increamemo-opener)
(require 'increamemo-test-support)

(defun increamemo-opener-test--item (path)
  "Return a file item plist for PATH."
  (list :id 42
        :type "file"
        :path path))

(ert-deftest increamemo-opener-opens-file-item-with-resolved-backend ()
  "Opening a file item returns the opened buffer."
  (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
    (let ((opened-buffer
           (increamemo-opener-open-item
            (increamemo-opener-test--item
             (expand-file-name buffer-file-name)))))
      (unwind-protect
          (should (equal (buffer-file-name opened-buffer)
                         (expand-file-name buffer-file-name)))
        (when (buffer-live-p opened-buffer)
          (kill-buffer opened-buffer))))))

(ert-deftest increamemo-opener-wraps-backend-errors ()
  "Opening fails with a classified opener error when the backend raises."
  (cl-letf (((symbol-function 'increamemo-backend-open-item)
             (lambda (_item)
               (error "broken backend"))))
    (should-error
     (increamemo-opener-open-item '(:id 42 :type "file"))
     :type 'increamemo-opener-error)))

(ert-deftest increamemo-opener-rejects-non-buffer-results ()
  "Opening fails when the backend does not return a live buffer."
  (cl-letf (((symbol-function 'increamemo-backend-open-item)
             (lambda (_item) nil)))
    (should-error
     (increamemo-opener-open-item '(:id 42 :type "file"))
     :type 'increamemo-opener-error)))

(provide 'increamemo-opener-test)
;;; increamemo-opener-test.el ends here
