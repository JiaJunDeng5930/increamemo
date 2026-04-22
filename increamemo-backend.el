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

;; Backend registry and type-specific dispatch.

;;; Code:

(require 'cl-lib)
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
  "Return BACKEND function named by SUFFIX."
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

(defun increamemo-backend--type-function (backend)
  "Return the type function for BACKEND."
  (increamemo-backend--function backend "type"))

(defun increamemo-backend--prompt-function (backend)
  "Return the manual prompt function for BACKEND."
  (increamemo-backend--function backend "prompt-new-item"))

(defun increamemo-backend--duplicate-function (backend)
  "Return the duplicate lookup function for BACKEND."
  (increamemo-backend--function backend "find-live-duplicate-id"))

(defun increamemo-backend--insert-function (backend)
  "Return the subtype insert function for BACKEND."
  (increamemo-backend--function backend "insert-item-data"))

(defun increamemo-backend--hydrate-function (backend)
  "Return the subtype hydration function for BACKEND."
  (increamemo-backend--function backend "hydrate-item"))

(defun increamemo-backend--open-function (backend)
  "Return the open function for BACKEND."
  (increamemo-backend--function backend "open-item"))

(defun increamemo-backend--find-by-type (type)
  "Return the configured backend that implements TYPE."
  (or
   (cl-find-if
    (lambda (backend)
      (string=
       (funcall (increamemo-backend--type-function backend))
       type))
    increamemo-backends)
   (user-error "Increamemo: no backend recognized type: %s" type)))

(defun increamemo-backend-supported-types ()
  "Return the configured backend type strings."
  (delete-dups
   (mapcar
    (lambda (backend)
      (funcall (increamemo-backend--type-function backend)))
    increamemo-backends)))

(defun increamemo-backend-identify-current (&optional buffer)
  "Return an item spec for BUFFER using the configured backends."
  (let ((target-buffer (or buffer (current-buffer)))
        (item-spec nil))
    (dolist (backend increamemo-backends)
      (unless item-spec
        (setq item-spec
              (funcall (increamemo-backend--recognizer backend)
                       target-buffer))))
    (or item-spec
        (user-error "Increamemo: no backend recognized the current buffer"))))

(defun increamemo-backend-prompt-new-item (type)
  "Prompt for a new item of TYPE and return its item spec."
  (funcall
   (increamemo-backend--prompt-function
    (increamemo-backend--find-by-type type))))

(defun increamemo-backend-build-source-ref (type locator &optional opener)
  "Return an item spec for TYPE and LOCATOR.

OPENER is accepted for compatibility and ignored."
  (ignore opener)
  (let ((backend (increamemo-backend--find-by-type type)))
    (cond
     ((fboundp (intern-soft (format "%s-build-source-ref" backend)))
      (funcall (intern-soft (format "%s-build-source-ref" backend))
               type locator opener))
     (t
      (user-error "Increamemo: backend %S does not support manual construction"
                  backend)))))

(defun increamemo-backend-find-live-duplicate-id (connection item-spec)
  "Return a live duplicate id for ITEM-SPEC on CONNECTION, or nil."
  (funcall
   (increamemo-backend--duplicate-function
    (increamemo-backend--find-by-type (plist-get item-spec :type)))
   connection
   item-spec))

(defun increamemo-backend-insert-item-data (connection item-id item-spec)
  "Insert subtype data for ITEM-ID and ITEM-SPEC on CONNECTION."
  (funcall
   (increamemo-backend--insert-function
    (increamemo-backend--find-by-type (plist-get item-spec :type)))
   connection
   item-id
   item-spec))

(defun increamemo-backend-hydrate-item (connection item)
  "Return ITEM enriched with subtype data loaded from CONNECTION."
  (funcall
   (increamemo-backend--hydrate-function
    (increamemo-backend--find-by-type (plist-get item :type)))
   connection
   item))

(defun increamemo-backend-open-item (item)
  "Open ITEM through its backend and return the resulting buffer."
  (funcall
   (increamemo-backend--open-function
    (increamemo-backend--find-by-type (plist-get item :type)))
   item))

(provide 'increamemo-backend)
;;; increamemo-backend.el ends here
