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

(provide 'increamemo-test-support)
;;; increamemo-test-support.el ends here
