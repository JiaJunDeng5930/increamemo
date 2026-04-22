;;; increamemo-backend.el --- Backend registry for increamemo  -*- lexical-binding: t; -*-

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

;; Backend registry and source-ref dispatch.

;;; Code:

(require 'subr-x)
(require 'increamemo-backend-ekg)
(require 'increamemo-backend-file)
(require 'increamemo-config)

(defun increamemo-backend--features (backend)
  "Return the feature names that may implement BACKEND."
  (let ((backend-name (symbol-name backend)))
    (delete-dups
     (delq nil
           (list
            backend
            (when (and (string-prefix-p "increamemo-" backend-name)
                       (string-suffix-p "-backend" backend-name))
              (intern
               (concat
                "increamemo-backend-"
                (string-remove-suffix
                 "-backend"
                 (string-remove-prefix "increamemo-" backend-name))))))))))

(defun increamemo-backend--function (backend suffix)
  "Return BACKEND function named by SUFFIX.

BACKEND follows the registry contract exposed by `increamemo-backends'."
  (unless (symbolp backend)
    (user-error "Increamemo: invalid backend: %S" backend))
  (dolist (feature (increamemo-backend--features backend))
    (unless (featurep feature)
      (require feature nil t)))
  (let ((function-symbol
         (intern-soft (format "%s-%s" backend suffix))))
    (unless (fboundp function-symbol)
      (user-error "Increamemo: unknown backend: %S" backend))
    function-symbol))

(defun increamemo-backend--recognizer (backend)
  "Return the recognizer function for BACKEND."
  (increamemo-backend--function backend "recognize-current"))

(defun increamemo-backend--builder (backend)
  "Return the manual source-ref builder for BACKEND."
  (increamemo-backend--function backend "build-source-ref"))

(defun increamemo-backend-identify-current (&optional buffer)
  "Return a source ref for BUFFER using the configured backends."
  (let ((target-buffer (or buffer (current-buffer)))
        (source-ref nil))
    (dolist (backend increamemo-backends)
      (unless source-ref
        (setq source-ref
              (funcall (increamemo-backend--recognizer backend)
                       target-buffer))))
    (or source-ref
        (user-error "Increamemo: no backend recognized the current buffer"))))

(defun increamemo-backend-build-source-ref (type locator &optional opener)
  "Return a source ref for TYPE, LOCATOR, and optional OPENER."
  (let ((source-ref nil))
    (dolist (backend increamemo-backends)
      (unless source-ref
        (setq source-ref
              (funcall (increamemo-backend--builder backend)
                       type
                       locator
                       opener))))
    (or source-ref
        (user-error "Increamemo: no backend recognized type: %s" type))))

(provide 'increamemo-backend)
;;; increamemo-backend.el ends here
