;;; increamemo-core-test.el --- Core tests for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for the initial project skeleton.

;;; Code:

(require 'ert)
(require 'increamemo)
(require 'increamemo-test-support)

(ert-deftest increamemo-public-commands-require-database-config ()
  "Public commands must fail fast when the database path is missing."
  (let ((increamemo-db-file nil))
    (dolist (command '(increamemo-init
                       increamemo-add-current
                       increamemo-work
                       increamemo-board))
      (should-error (funcall command) :type 'user-error))))

(ert-deftest increamemo-init-creates-base-schema ()
  "Initialization creates the initial tables and schema version."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (should (file-exists-p increamemo-db-file))
    (dolist (table-name '("increamemo_meta"
                          "increamemo_items"
                          "increamemo_history"))
      (should
       (increamemo-test-support-table-exists-p
        increamemo-db-file
        table-name)))
    (should
     (equal (increamemo-test-support-schema-version increamemo-db-file)
            increamemo-migration-schema-version))))

(ert-deftest increamemo-init-is-idempotent ()
  "Repeated initialization keeps the schema version stable."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-init)
    (should
     (equal (increamemo-test-support-schema-version increamemo-db-file)
            increamemo-migration-schema-version))))

(provide 'increamemo-core-test)
;;; increamemo-core-test.el ends here
