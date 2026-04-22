;;; increamemo-storage.el --- SQLite access for increamemo  -*- lexical-binding: t; -*-

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

;; Low-level SQLite helpers.

;;; Code:

(require 'sqlite)

(declare-function sqlite-close "sqlite" (connection))
(declare-function sqlite-execute "sqlite" (connection sql &optional values))
(declare-function sqlite-open "sqlite" (file))
(declare-function sqlite-select "sqlite" (connection sql &optional values))

(defun increamemo-storage-require-sqlite ()
  "Require SQLite support in this Emacs."
  (unless (sqlite-available-p)
    (user-error "Increamemo: this Emacs was built without SQLite support")))

(defun increamemo-storage-open (db-file)
  "Open SQLite connection for DB-FILE."
  (increamemo-storage-require-sqlite)
  (sqlite-open db-file))

(defun increamemo-storage-close (connection)
  "Close SQLite CONNECTION."
  (sqlite-close connection))

(defun increamemo-storage-execute (connection sql &optional values)
  "Execute SQL with VALUES on CONNECTION."
  (sqlite-execute connection sql values))

(defun increamemo-storage-select (connection sql &optional values)
  "Run select SQL with VALUES on CONNECTION."
  (sqlite-select connection sql values))

(defun increamemo-storage-select-value (connection sql &optional values)
  "Return the first column of the first row for SQL on CONNECTION."
  (car (car (increamemo-storage-select connection sql values))))

(defmacro increamemo-storage-with-transaction (connection &rest body)
  "Execute BODY in an immediate SQLite transaction on CONNECTION."
  (declare (indent 1) (debug t))
  `(progn
     (increamemo-storage-execute ,connection "BEGIN IMMEDIATE TRANSACTION")
     (condition-case err
         (let ((result (progn ,@body)))
           (increamemo-storage-execute ,connection "COMMIT")
           result)
       (error
        (increamemo-storage-execute ,connection "ROLLBACK")
        (signal (car err) (cdr err))))))

(provide 'increamemo-storage)
;;; increamemo-storage.el ends here
