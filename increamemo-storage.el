;;; increamemo-storage.el --- SQLite access for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Low-level SQLite helpers.

;;; Code:

(declare-function sqlite-close "sqlite" (connection))
(declare-function sqlite-execute "sqlite" (connection sql &optional values))
(declare-function sqlite-open "sqlite" (file))
(declare-function sqlite-select "sqlite" (connection sql &optional values))

(defun increamemo-storage-open (db-file)
  "Open SQLite connection for DB-FILE."
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
