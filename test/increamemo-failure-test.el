;;; increamemo-failure-test.el --- Failure policy tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for open failure handling.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-board)
(require 'increamemo-domain)
(require 'increamemo-test-support)
(require 'increamemo-work)

(defun increamemo-failure-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :locator path
        :opener 'find-file
        :title-snapshot (file-name-nondirectory path)))

(defmacro increamemo-failure-test-with-work-start (policy &rest body)
  "Run BODY after starting work with POLICY on one broken and one valid item."
  (declare (indent 1) (debug (form body)))
  `(increamemo-test-support-with-temp-db
     (increamemo-init)
     (let ((increamemo-invalid-opener-policy ,policy))
       (let* ((broken-item
               (increamemo-domain-ensure-item
                (increamemo-failure-test--source-ref
                 "/tmp/increamemo-missing-note.md")
                10
                "2026-04-21"
                "2026-04-21T08:00:00+00:00"))
              (captured-message nil))
         (increamemo-test-support-with-file-buffer "notes/topic.md" "topic"
           (let ((valid-path (expand-file-name buffer-file-name)))
             (increamemo-domain-ensure-item
              (increamemo-failure-test--source-ref valid-path)
              20
              "2026-04-21"
              "2026-04-21T08:01:00+00:00")
             (cl-letf (((symbol-function 'increamemo-time-today)
                        (lambda () "2026-04-21"))
                       ((symbol-function 'message)
                        (lambda (format-string &rest args)
                          (setq captured-message
                                (apply #'format format-string args)))))
               (let ((opened-buffer (increamemo-work-start)))
                 (unwind-protect
                     (let ((broken-id (plist-get broken-item :id)))
                       ,@body)
                   (when (buffer-live-p opened-buffer)
                     (with-current-buffer opened-buffer
                       (increamemo-work-quit))
                     (kill-buffer opened-buffer)))))))))))

(ert-deftest increamemo-work-start-keep-policy-marks-item-invalid ()
  "Open failure policy keep marks the failing item invalid and continues."
  (increamemo-failure-test-with-work-start 'keep
    (should (equal (buffer-file-name opened-buffer) valid-path))
    (should (= (increamemo-session-handled-count increamemo-work--session) 1))
    (should (string-match-p "failed to open item" captured-message))
    (should
     (equal
      (increamemo-test-support-select-row
       increamemo-db-file
       "SELECT state, last_error FROM increamemo_items WHERE id = ?"
       (list broken-id))
      (list "invalid"
            "Increamemo: file does not exist: /tmp/increamemo-missing-note.md")))
    (should
     (= 1
        (increamemo-test-support-count-rows
         increamemo-db-file
         "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'open_failed'"
         (list broken-id))))))

(ert-deftest increamemo-work-start-archive-policy-archives-item ()
  "Open failure policy archive archives the failing item and continues."
  (increamemo-failure-test-with-work-start 'archive
    (should (equal (buffer-file-name opened-buffer) valid-path))
    (should (= (increamemo-session-handled-count increamemo-work--session) 1))
    (should
     (equal
      (car
       (increamemo-test-support-select-row
        increamemo-db-file
        "SELECT state FROM increamemo_items WHERE id = ?"
        (list broken-id)))
      "archived"))
    (should
     (= 1
        (increamemo-test-support-count-rows
         increamemo-db-file
         "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'open_failed'"
         (list broken-id))))
    (should
     (= 1
        (increamemo-test-support-count-rows
         increamemo-db-file
         "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'archived'"
         (list broken-id))))))

(ert-deftest increamemo-work-start-delete-policy-removes-item ()
  "Open failure policy delete removes the failing item and continues."
  (increamemo-failure-test-with-work-start 'delete
    (should (equal (buffer-file-name opened-buffer) valid-path))
    (should (= (increamemo-session-handled-count increamemo-work--session) 1))
    (should
     (= 0
        (increamemo-test-support-count-rows
         increamemo-db-file
         "SELECT COUNT(*) FROM increamemo_items WHERE id = ?"
         (list broken-id))))
    (should
     (= 1
        (increamemo-test-support-count-rows
         increamemo-db-file
         "SELECT COUNT(*) FROM increamemo_items WHERE state = 'active'")))))

(ert-deftest increamemo-board-open-invalid-item-keep-policy-refreshes-error ()
  "Reopening an invalid item under keep policy preserves invalid state."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-invalid-opener-policy 'keep)
          (captured-message nil)
          (item nil))
      (setq item
            (increamemo-domain-ensure-item
             (increamemo-failure-test--source-ref
              "/tmp/increamemo-missing-note.md")
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
      (increamemo-domain-mark-invalid
       (plist-get item :id)
       "old error"
       "2026-04-21T08:30:00+00:00")
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21"))
                ((symbol-function 'increamemo-time-now)
                 (lambda () "2026-04-21T09:00:00+00:00"))
                ((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (setq captured-message
                         (apply #'format format-string args)))))
        (let ((buffer (increamemo-board-open)))
          (unwind-protect
              (with-current-buffer buffer
                (increamemo-board-show-invalid)
                (increamemo-board-open-current-item)
                (should (string-match-p "failed to open item" captured-message))
                (should
                 (equal
                  (increamemo-test-support-select-row
                   increamemo-db-file
                   "SELECT state, last_error FROM increamemo_items WHERE id = ?"
                   (list (plist-get item :id)))
                  (list
                   "invalid"
                   "Increamemo: file does not exist: /tmp/increamemo-missing-note.md")))
                (should (= 2
                           (increamemo-test-support-count-rows
                            increamemo-db-file
                            (concat
                             "SELECT COUNT(*) FROM increamemo_history "
                             "WHERE item_id = ? AND action = 'open_failed'")
                            (list (plist-get item :id))))))
            (kill-buffer buffer)))))))

(ert-deftest increamemo-board-open-broken-item-archive-policy-refreshes-list ()
  "Board open failure with archive policy archives the item and refreshes rows."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-invalid-opener-policy 'archive)
          (item nil))
      (setq item
            (increamemo-domain-ensure-item
             (increamemo-failure-test--source-ref
              "/tmp/increamemo-missing-note.md")
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21"))
                ((symbol-function 'increamemo-time-now)
                 (lambda () "2026-04-21T09:00:00+00:00"))
                ((symbol-function 'message)
                 (lambda (&rest _args) nil)))
        (let ((buffer (increamemo-board-open)))
          (unwind-protect
              (with-current-buffer buffer
                (increamemo-board-show-planned)
                (increamemo-board-open-current-item)
                (should-not tabulated-list-entries)
                (should
                 (equal
                  (car
                   (increamemo-test-support-select-row
                    increamemo-db-file
                    "SELECT state FROM increamemo_items WHERE id = ?"
                    (list (plist-get item :id))))
                  "archived")))
            (kill-buffer buffer)))))))

(ert-deftest increamemo-board-open-broken-item-delete-policy-removes-row ()
  "Board open failure with delete policy removes the item and refreshes rows."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-invalid-opener-policy 'delete)
          (item nil))
      (setq item
            (increamemo-domain-ensure-item
             (increamemo-failure-test--source-ref
              "/tmp/increamemo-missing-note.md")
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00"))
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21"))
                ((symbol-function 'increamemo-time-now)
                 (lambda () "2026-04-21T09:00:00+00:00"))
                ((symbol-function 'message)
                 (lambda (&rest _args) nil)))
        (let ((buffer (increamemo-board-open)))
          (unwind-protect
              (with-current-buffer buffer
                (increamemo-board-show-planned)
                (increamemo-board-open-current-item)
                (should-not tabulated-list-entries)
                (should
                 (= 0
                    (increamemo-test-support-count-rows
                     increamemo-db-file
                     "SELECT COUNT(*) FROM increamemo_items WHERE id = ?"
                     (list (plist-get item :id))))))
            (kill-buffer buffer)))))))

(provide 'increamemo-failure-test)
;;; increamemo-failure-test.el ends here
