;;; increamemo-core-test.el --- Core tests for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for the initial project skeleton.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-board)
(require 'increamemo-work)
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

(ert-deftest increamemo-board-add-item-gates-config-before-prompting ()
  "Board item creation checks configuration before asking for input."
  (let ((increamemo-db-file nil)
        (prompted nil))
    (cl-letf (((symbol-function 'read-string)
               (lambda (&rest _args)
                 (setq prompted t)
                 "ignored"))
              ((symbol-function 'read-number)
               (lambda (&rest _args)
                 (setq prompted t)
                 1)))
      (should-error (increamemo-board-add-item) :type 'user-error)
      (should-not prompted))))

(ert-deftest increamemo-work-start-gates-config-before-runtime-setup ()
  "Work runtime start checks configuration before creating a session."
  (let ((increamemo-db-file nil))
    (should-error (increamemo-work-start) :type 'user-error)))

(ert-deftest increamemo-public-commands-require-initialized-schema ()
  "Commands that rely on persisted state stop before running on an uninitialized DB."
  (increamemo-test-support-with-temp-db
    (when (file-exists-p increamemo-db-file)
      (delete-file increamemo-db-file))
    (let ((prompted nil))
      (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
        (cl-letf (((symbol-function 'read-number)
                   (lambda (&rest _args)
                     (setq prompted t)
                     10)))
          (should-error (increamemo-add-current) :type 'user-error)
          (should-not prompted)))
      (should-error (increamemo-work) :type 'user-error)
      (should-error (increamemo-board) :type 'user-error)
      (should-not (file-exists-p increamemo-db-file)))))

(provide 'increamemo-core-test)
;;; increamemo-core-test.el ends here
