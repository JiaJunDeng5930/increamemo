;;; increamemo-domain-test.el --- Domain tests for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for scheduling domain commands.

;;; Code:

(require 'ert)
(require 'increamemo)
(require 'increamemo-domain)
(require 'increamemo-test-support)

(defun increamemo-domain-test--source-ref (locator)
  "Build a file source reference for LOCATOR."
  (list :type "file"
        :locator locator
        :opener 'find-file
        :title-snapshot (file-name-nondirectory locator)))

(ert-deftest increamemo-domain-ensure-item-creates-active-item-and-history ()
  "Ensuring a new item creates one active row and one created history row."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((item (increamemo-domain-ensure-item
                 (increamemo-domain-test--source-ref "/tmp/notes/alpha.md")
                 10
                 "2026-04-21"
                 "2026-04-21T08:00:00+00:00")))
      (should (equal (plist-get item :type) "file"))
      (should (equal (plist-get item :locator) "/tmp/notes/alpha.md"))
      (should (equal (plist-get item :opener) "find-file"))
      (should (equal (plist-get item :state) "active"))
      (should (equal (plist-get item :next-due-date) "2026-04-21"))
      (should (= (plist-get item :priority) 10))
      (should
       (= 1
          (increamemo-test-support-count-rows
           increamemo-db-file
           "SELECT COUNT(*) FROM increamemo_items")))
      (should
       (= 1
          (increamemo-test-support-count-rows
           increamemo-db-file
           "SELECT COUNT(*) FROM increamemo_history WHERE action = 'created'"))))))

(ert-deftest increamemo-domain-ensure-item-reuses-live-duplicate ()
  "Ensuring a live duplicate returns the existing item without new writes."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((source (increamemo-domain-test--source-ref "/tmp/notes/alpha.md"))
           (created (increamemo-domain-ensure-item
                     source
                     10
                     "2026-04-21"
                     "2026-04-21T08:00:00+00:00"))
           (existing (increamemo-domain-ensure-item
                      source
                      30
                      "2026-04-23"
                      "2026-04-21T09:00:00+00:00")))
      (should (= (plist-get created :id)
                 (plist-get existing :id)))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_items")))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_history"))))))

(ert-deftest increamemo-domain-list-due-orders-items-and-excludes-session-skips ()
  "Due items sort by priority, due date, and creation order."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((first (increamemo-domain-ensure-item
                   (increamemo-domain-test--source-ref "/tmp/notes/first.md")
                   40
                   "2026-04-21"
                   "2026-04-21T08:00:00+00:00"))
           (_second (increamemo-domain-ensure-item
                     (increamemo-domain-test--source-ref "/tmp/notes/second.md")
                     20
                     "2026-04-21"
                     "2026-04-21T08:01:00+00:00"))
           (_third (increamemo-domain-ensure-item
                    (increamemo-domain-test--source-ref "/tmp/notes/third.md")
                    20
                    "2026-04-20"
                    "2026-04-21T08:02:00+00:00"))
           (_future (increamemo-domain-ensure-item
                     (increamemo-domain-test--source-ref "/tmp/notes/future.md")
                     0
                     "2026-04-22"
                     "2026-04-21T08:03:00+00:00"))
           (items (increamemo-domain-list-due
                   "2026-04-21"
                   (list (plist-get first :id)))))
      (should (equal (mapcar (lambda (item) (plist-get item :locator)) items)
                     '("/tmp/notes/third.md"
                       "/tmp/notes/second.md"))))))

(ert-deftest increamemo-domain-item-updates-write-history ()
  "Archiving, deferring, and reprioritizing update the row and append history."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((archived-item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/archive.md")
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (deferred-item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/defer.md")
             20
             "2026-04-21"
             "2026-04-21T08:01:00+00:00"))
           (reprioritized-item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/priority.md")
             30
             "2026-04-21"
             "2026-04-21T08:02:00+00:00"))
           (archived-result
            (increamemo-domain-archive-item
             (plist-get archived-item :id)
             "2026-04-21T09:00:00+00:00"))
           (deferred-result
            (increamemo-domain-defer-item
             (plist-get deferred-item :id)
             "2026-04-25"
             "2026-04-21T09:01:00+00:00"))
           (updated-result
            (increamemo-domain-update-priority
             (plist-get reprioritized-item :id)
             5
             "2026-04-21T09:02:00+00:00")))
      (should (eq (plist-get archived-result :status) 'archived))
      (should (eq (plist-get deferred-result :status) 'deferred))
      (should (eq (plist-get updated-result :status) 'updated))
      (let ((archived-row
             (increamemo-test-support-select-row
              increamemo-db-file
              "SELECT state FROM increamemo_items WHERE id = ?"
              (list (plist-get archived-item :id))))
            (deferred-row
             (increamemo-test-support-select-row
              increamemo-db-file
              "SELECT next_due_date FROM increamemo_items WHERE id = ?"
              (list (plist-get deferred-item :id))))
            (priority-row
             (increamemo-test-support-select-row
              increamemo-db-file
              "SELECT priority FROM increamemo_items WHERE id = ?"
              (list (plist-get reprioritized-item :id)))))
        (should (equal (car archived-row) "archived"))
        (should (equal (car deferred-row) "2026-04-25"))
        (should (= (car priority-row) 5))
        (should (= 6
                   (increamemo-test-support-count-rows
                    increamemo-db-file
                    "SELECT COUNT(*) FROM increamemo_history")))))))

(ert-deftest increamemo-domain-skip-item-writes-history-without-state-change ()
  "Skipping an item keeps its scheduling data and appends history."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/skip.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (skipped-item
            (increamemo-domain-skip-item
             (plist-get item :id)
             "2026-04-21T09:00:00+00:00")))
      (should (eq (plist-get skipped-item :status) 'skipped))
      (should (equal (plist-get skipped-item :state) "active"))
      (should (equal (plist-get skipped-item :next-due-date) "2026-04-21"))
      (should
       (equal
        (increamemo-test-support-select-row
         increamemo-db-file
         "SELECT state, next_due_date, version, updated_at FROM increamemo_items WHERE id = ?"
         (list (plist-get item :id)))
        '("active" "2026-04-21" 0 "2026-04-21T08:00:00+00:00")))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'skipped'"
                  (list (plist-get item :id))))))))

(ert-deftest increamemo-domain-delete-item-removes-row-and-writes-history ()
  "Deleting an item removes the row and appends one deleted history row."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/delete.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (item-id (plist-get item :id))
           (result
            (increamemo-domain-delete-item
             item-id
             "2026-04-21T09:00:00+00:00")))
      (should (eq (plist-get result :status) 'deleted))
      (should (= 0
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_items WHERE id = ?"
                  (list item-id))))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'deleted'"
                  (list item-id)))))
    (let ((missing
           (increamemo-domain-delete-item
            9999
            "2026-04-21T10:00:00+00:00")))
      (should (eq (plist-get missing :status) 'deleted)))))

(ert-deftest increamemo-domain-archive-item-is-idempotent-for-archived-items ()
  "Archiving an archived item returns the same archived state."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/archive.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (archived
            (increamemo-domain-archive-item
             (plist-get item :id)
             "2026-04-21T09:00:00+00:00"))
           (archived-again
            (increamemo-domain-archive-item
             (plist-get item :id)
             "2026-04-21T10:00:00+00:00")))
      (should (eq (plist-get archived :status) 'archived))
      (should (eq (plist-get archived-again :status) 'archived))
      (should (equal (plist-get archived :state) "archived"))
      (should (equal (plist-get archived-again :state) "archived"))
      (should (= 2
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ?"
                  (list (plist-get item :id))))))))

(ert-deftest increamemo-domain-update-due-date-returns-updated-status ()
  "Updating due date returns the documented updated status."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/due-status.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (result
            (increamemo-domain-update-due-date
             (plist-get item :id)
             "2026-04-25"
             "2026-04-21T09:00:00+00:00")))
      (should (eq (plist-get result :status) 'updated))
      (should (equal (plist-get result :next-due-date) "2026-04-25")))))

(ert-deftest increamemo-domain-update-due-date-allows-archived-items ()
  "Updating due date preserves archived state for archived items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/archived-due.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (_archived
            (increamemo-domain-archive-item
             (plist-get item :id)
             "2026-04-21T08:30:00+00:00"))
           (result
            (increamemo-domain-update-due-date
             (plist-get item :id)
             "2026-04-25"
             "2026-04-21T09:00:00+00:00")))
      (should (eq (plist-get result :status) 'updated))
      (should (equal (plist-get result :state) "archived"))
      (should (equal (plist-get result :next-due-date) "2026-04-25")))))

(ert-deftest increamemo-domain-update-priority-aborts-when-version-check-fails ()
  "Version-guarded updates stop when the item row is not updated."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/conflict.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (original-guarded-update
            (symbol-function 'increamemo-domain--execute-guarded-update)))
      (cl-letf (((symbol-function 'increamemo-domain--execute-guarded-update)
                 (lambda (connection sql values)
                   (if (string-match-p "\\`UPDATE increamemo_items" sql)
                       0
                     (funcall original-guarded-update connection sql values)))))
        (should-error
         (increamemo-domain-update-priority
          (plist-get item :id)
          5
          "2026-04-21T09:00:00+00:00")
         :type 'user-error))
      (should
       (equal
        (increamemo-test-support-select-row
         increamemo-db-file
         "SELECT priority, version FROM increamemo_items WHERE id = ?"
         (list (plist-get item :id)))
        '(15 0)))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ?"
                  (list (plist-get item :id))))))))

(ert-deftest increamemo-domain-update-priority-rereads-when-item-was-deleted ()
  "Priority updates re-read and surface deletion when the item vanished."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((item
            (increamemo-domain-ensure-item
             (increamemo-domain-test--source-ref "/tmp/notes/deleted-conflict.md")
             15
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
           (item-id (plist-get item :id))
           (original-guarded-update
            (symbol-function 'increamemo-domain--execute-guarded-update)))
      (cl-letf (((symbol-function 'increamemo-domain--execute-guarded-update)
                 (lambda (connection sql values)
                   (if (string-match-p "\\`UPDATE increamemo_items" sql)
                       (progn
                         (increamemo-storage-execute
                         connection
                          "DELETE FROM increamemo_items WHERE id = ?"
                          (list item-id))
                         0)
                     (funcall original-guarded-update connection sql values)))))
        (let ((err
               (should-error
                (increamemo-domain-update-priority
                 item-id
                 5
                 "2026-04-21T09:00:00+00:00")
                :type 'user-error)))
          (should
           (equal (error-message-string err)
                  (format "Increamemo: item %s does not exist" item-id)))))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_items WHERE id = ?"
                  (list item-id))))
      (should (= 1
                 (increamemo-test-support-count-rows
                  increamemo-db-file
                  "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ?"
                  (list item-id)))))))

(provide 'increamemo-domain-test)
;;; increamemo-domain-test.el ends here
