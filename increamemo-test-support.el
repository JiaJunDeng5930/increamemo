;;; increamemo-test-support.el --- Test helpers for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Shared helpers for regression tests.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-storage)

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

(provide 'increamemo-test-support)
;;; increamemo-test-support.el ends here
