;;; increamemo-complete-test.el --- Completion tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for completion flow and rescheduling policy.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-domain)
(require 'increamemo-policy)
(require 'increamemo-test-support)
(require 'increamemo-work)

(defun increamemo-complete-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :locator path
        :opener 'find-file
        :title-snapshot (file-name-nondirectory path)))

(ert-deftest increamemo-policy-compute-next-due-date-validates-callback-result ()
  "The reschedule policy adapter returns a validated due date."
  (let ((increamemo-reschedule-function
         (lambda (item action)
           (should (equal (plist-get item :id) 7))
           (should (eq action 'complete))
           "2026-04-25")))
    (should
     (equal
      (increamemo-policy-compute-next-due-date
       (list :id 7 :custom-json nil)
       'complete
       '(:history-count 2)
       "2026-04-21")
      "2026-04-25"))))

(ert-deftest increamemo-domain-complete-current-reschedules-and-writes-history ()
  "Completing a due item updates the due date and appends history."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-reschedule-function
           (lambda (_item _action) "2026-04-28")))
      (let* ((item
              (increamemo-domain-ensure-item
               (list :type "file"
                     :locator "/tmp/topic.md"
                     :opener 'find-file
                     :title-snapshot "topic.md")
               10
               "2026-04-21"
               "2026-04-21T08:00:00+00:00"))
             (result
              (increamemo-domain-complete-current
               (plist-get item :id)
               "2026-04-21"
               "2026-04-21T09:00:00+00:00")))
        (should (eq (plist-get result :status) 'completed))
        (should (equal (plist-get (plist-get result :item) :next-due-date)
                       "2026-04-28"))
        (should
         (equal
          (car
           (increamemo-test-support-select-row
            increamemo-db-file
            "SELECT last_reviewed_at FROM increamemo_items WHERE id = ?"
            (list (plist-get item :id))))
          "2026-04-21T09:00:00+00:00"))
        (should
         (= 2
            (increamemo-test-support-count-rows
             increamemo-db-file
             "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ?"
             (list (plist-get item :id)))))))))

(ert-deftest increamemo-domain-complete-current-returns-stale-without-write ()
  "Completing a non-due item returns stale and keeps persistent state unchanged."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-reschedule-function
           (lambda (_item _action) "2026-04-28")))
      (let* ((item
              (increamemo-domain-ensure-item
               (list :type "file"
                     :locator "/tmp/topic.md"
                     :opener 'find-file
                     :title-snapshot "topic.md")
               10
               "2026-04-24"
               "2026-04-21T08:00:00+00:00"))
             (result
              (increamemo-domain-complete-current
               (plist-get item :id)
               "2026-04-21"
               "2026-04-21T09:00:00+00:00")))
        (should (eq (plist-get result :status) 'stale))
        (should
         (= 1
            (increamemo-test-support-count-rows
             increamemo-db-file
             "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ?"
             (list (plist-get item :id)))))
        (should
         (equal
          (car
           (increamemo-test-support-select-row
            increamemo-db-file
            "SELECT next_due_date FROM increamemo_items WHERE id = ?"
            (list (plist-get item :id))))
          "2026-04-24"))))))

(ert-deftest increamemo-work-complete-reschedules-and-opens-next-item ()
  "Completing the current work item advances the session to the next due item."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-reschedule-function
           (lambda (_item _action) "2026-04-28")))
      (increamemo-test-support-with-file-buffer "notes/first.md" "first"
        (let ((first-path (expand-file-name buffer-file-name)))
          (increamemo-domain-ensure-item
           (increamemo-complete-test--source-ref first-path)
           10
           "2026-04-21"
           "2026-04-21T08:00:00+00:00"))
        (increamemo-test-support-with-file-buffer "notes/second.md" "second"
          (let ((second-path (expand-file-name buffer-file-name)))
            (increamemo-domain-ensure-item
             (increamemo-complete-test--source-ref second-path)
             20
             "2026-04-21"
             "2026-04-21T08:01:00+00:00")
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda () "2026-04-21T09:00:00+00:00")))
              (let ((opened-buffer (increamemo-work-start)))
                (unwind-protect
                    (with-current-buffer opened-buffer
                      (let ((next-buffer (increamemo-work-complete)))
                        (with-current-buffer next-buffer
                          (should increamemo-work-mode)
                          (should (equal (buffer-file-name)
                                         second-path))
                          (should (equal (increamemo-work--mode-line-text)
                                         "IM[1/1]")))))
                  (when (buffer-live-p opened-buffer)
                    (kill-buffer opened-buffer)))))))))))

(provide 'increamemo-complete-test)
;;; increamemo-complete-test.el ends here
