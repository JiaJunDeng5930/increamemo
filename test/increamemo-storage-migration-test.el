;;; increamemo-storage-migration-test.el --- Storage and migration tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for storage transactions and schema migration.

;;; Code:

(require 'ert)
(require 'increamemo)
(require 'increamemo-storage)
(require 'increamemo-test-support)

(ert-deftest increamemo-storage-with-transaction-rolls-back-on-error ()
  "Transactions leave no committed rows when the body errors."
  (increamemo-test-support-with-temp-db
    (let ((connection (increamemo-storage-open increamemo-db-file)))
      (unwind-protect
          (progn
            (increamemo-storage-execute
             connection
             "CREATE TABLE entries (value TEXT NOT NULL)")
            (should-error
             (increamemo-storage-with-transaction connection
               (increamemo-storage-execute
                connection
                "INSERT INTO entries(value) VALUES(?)"
                '("kept-out"))
               (error "boom"))
             :type 'error)
            (should-not
             (increamemo-storage-select-value
              connection
              "SELECT value FROM entries LIMIT 1")))
        (increamemo-storage-close connection)))))

(ert-deftest increamemo-init-upgrades-known-older-schema ()
  "Initialization upgrades a supported older schema in place."
  (increamemo-test-support-with-temp-db
    (let ((connection (increamemo-storage-open increamemo-db-file)))
      (unwind-protect
          (progn
            (increamemo-storage-execute
             connection
             "CREATE TABLE increamemo_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )")
            (increamemo-storage-execute
             connection
             "INSERT INTO increamemo_meta(key, value) VALUES(?, ?)"
             '("schema-version" "0")))
        (increamemo-storage-close connection)))
    (increamemo-init)
    (should
     (equal (increamemo-test-support-schema-version increamemo-db-file)
            increamemo-migration-schema-version))
    (dolist (table-name '("increamemo_meta"
                          "increamemo_items"
                          "increamemo_history"))
      (should
       (increamemo-test-support-table-exists-p
        increamemo-db-file
        table-name)))))

(ert-deftest increamemo-init-rejects-newer-schema-version ()
  "Initialization stops when the database schema is newer than supported."
  (increamemo-test-support-with-temp-db
    (let ((connection (increamemo-storage-open increamemo-db-file)))
      (unwind-protect
          (progn
            (increamemo-storage-execute
             connection
             "CREATE TABLE increamemo_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )")
            (increamemo-storage-execute
             connection
             "INSERT INTO increamemo_meta(key, value) VALUES(?, ?)"
             '("schema-version" "99")))
        (increamemo-storage-close connection)))
    (should-error (increamemo-init) :type 'user-error)))

(provide 'increamemo-storage-migration-test)
;;; increamemo-storage-migration-test.el ends here
