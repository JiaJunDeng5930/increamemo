;;; increamemo-test-support.el --- Test helpers for increamemo  -*- lexical-binding: t; -*-

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

;; Shared helpers for regression tests.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-storage)

(defconst increamemo-test-support--project-root
  (expand-file-name
   ".."
   (file-name-directory (or load-file-name buffer-file-name default-directory)))
  "Project root directory used by test support.")

(defmacro increamemo-test-support-with-temp-db (&rest body)
  "Run BODY with a temporary database file."
  (declare (indent 0) (debug t))
  `(let* ((temp-dir (make-temp-file "increamemo-test-" t))
          (increamemo-db-file (expand-file-name "increamemo.sqlite" temp-dir)))
     (unwind-protect
         (progn ,@body)
       (delete-directory temp-dir t))))

(defmacro increamemo-test-support-with-file-buffer
    (filename contents &rest body)
  "Run BODY with a visiting buffer for FILENAME containing CONTENTS."
  (declare (indent 2) (debug (form form body)))
  `(let* ((temp-dir (make-temp-file "increamemo-test-file-" t))
          (file-path (expand-file-name ,filename temp-dir)))
     (unwind-protect
         (progn
           (make-directory (file-name-directory file-path) t)
           (with-temp-file file-path
             (insert ,contents))
           (let ((buffer (find-file-noselect file-path)))
             (unwind-protect
                 (with-current-buffer buffer
                   ,@body)
               (when (buffer-live-p buffer)
                 (kill-buffer buffer)))))
       (delete-directory temp-dir t))))

(defun increamemo-test-support-table-exists-p (db-file table-name)
  "Return non-nil when TABLE-NAME exists in DB-FILE."
  (let ((connection (increamemo-storage-open db-file)))
    (unwind-protect
        (increamemo-storage-select-value
         connection
         "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"
         (list table-name))
      (increamemo-storage-close connection))))

(defun increamemo-test-support-schema-version (db-file)
  "Return schema version recorded in DB-FILE."
  (let ((connection (increamemo-storage-open db-file)))
    (unwind-protect
        (increamemo-storage-select-value
         connection
         "SELECT value FROM increamemo_meta WHERE key = ?"
         '("schema-version"))
      (increamemo-storage-close connection))))

(defun increamemo-test-support-count-rows (db-file sql &optional values)
  "Return the count from SQL on DB-FILE with VALUES."
  (let ((connection (increamemo-storage-open db-file)))
    (unwind-protect
        (increamemo-storage-select-value connection sql values)
      (increamemo-storage-close connection))))

(defun increamemo-test-support-select-row (db-file sql &optional values)
  "Return the first row from SQL on DB-FILE with VALUES."
  (let ((connection (increamemo-storage-open db-file)))
    (unwind-protect
        (car (increamemo-storage-select connection sql values))
      (increamemo-storage-close connection))))

(defun increamemo-test-support-project-elisp-files ()
  "Return the main project Emacs Lisp files."
  (directory-files increamemo-test-support--project-root t "\\`increamemo.*\\.el\\'"))

(defun increamemo-test-support-read-file (file)
  "Return FILE contents as a string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(provide 'increamemo-test-support)
;;; increamemo-test-support.el ends here
