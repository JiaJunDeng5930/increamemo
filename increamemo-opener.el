;;; increamemo-opener.el --- Opening side effects for increamemo  -*- lexical-binding: t; -*-

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

;; Opening side effects and failure classification.

;;; Code:

(require 'increamemo-backend)

(define-error 'increamemo-opener-error "Increamemo opener error")

(defun increamemo-opener--signal (reason item format-string &rest args)
  "Signal an opener error for ITEM with REASON using FORMAT-STRING and ARGS."
  (let ((message-text (apply #'format format-string args)))
    (signal 'increamemo-opener-error
            (list (list :reason reason
                        :item item
                        :message message-text)))))

(defun increamemo-opener-open-item (item)
  "Open ITEM and return the resulting buffer."
  (condition-case err
      (let ((buffer (increamemo-backend-open-item item)))
        (unless (buffer-live-p buffer)
          (increamemo-opener--signal
           'invalid-buffer item "Increamemo: backend did not return a live buffer"))
        buffer)
    (increamemo-opener-error
     (signal (car err) (cdr err)))
    (user-error
     (increamemo-opener--signal
      'opener-error item "%s"
      (error-message-string err)))
    (error
     (increamemo-opener--signal
      'opener-error item "Increamemo: open failed: %s"
      (error-message-string err)))))

(provide 'increamemo-opener)
;;; increamemo-opener.el ends here
