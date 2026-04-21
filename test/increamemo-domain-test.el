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
             "2026-04-21T08:02:00+00:00")))
      (increamemo-domain-archive-item
       (plist-get archived-item :id)
       "2026-04-21T09:00:00+00:00")
      (increamemo-domain-defer-item
       (plist-get deferred-item :id)
       "2026-04-25"
       "2026-04-21T09:01:00+00:00")
      (increamemo-domain-update-priority
       (plist-get reprioritized-item :id)
       5
       "2026-04-21T09:02:00+00:00")
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

(provide 'increamemo-domain-test)
;;; increamemo-domain-test.el ends here
