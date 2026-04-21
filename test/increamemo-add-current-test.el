;;; increamemo-add-current-test.el --- add-current tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for the add-current entrypoint.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-test-support)

(ert-deftest increamemo-add-current-creates-active-item-from-current-file ()
  "Adding the current file creates one active item due today."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-supported-file-formats '("md"))
          (increamemo-file-openers '(("md" . find-file)))
          (captured-message nil))
      (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
        (cl-letf (((symbol-function 'read-number)
                   (lambda (prompt)
                     (should (equal prompt "Priority: "))
                     10))
                  ((symbol-function 'increamemo-time-today)
                   (lambda () "2026-04-21"))
                  ((symbol-function 'increamemo-time-now)
                   (lambda () "2026-04-21T08:00:00+00:00"))
                  ((symbol-function 'message)
                   (lambda (format-string &rest args)
                     (setq captured-message
                           (apply #'format format-string args)))))
          (increamemo-add-current)
          (let ((row
                 (increamemo-test-support-select-row
                  increamemo-db-file
                  (concat
                   "SELECT type, locator, opener, next_due_date, priority, state "
                   "FROM increamemo_items LIMIT 1"))))
            (should (equal row
                           (list "file"
                                 (expand-file-name buffer-file-name)
                                 "find-file"
                                 "2026-04-21"
                                 10
                                 "active"))))
          (should (= 1
                     (increamemo-test-support-count-rows
                      increamemo-db-file
                      "SELECT COUNT(*) FROM increamemo_history WHERE action = 'created'")))
          (should (string-match-p "Increamemo: added item" captured-message)))))))

(ert-deftest increamemo-add-current-reuses-existing-live-item ()
  "Adding the same current file twice reuses the existing live item."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-supported-file-formats '("md"))
          (increamemo-file-openers '(("md" . find-file))))
      (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
        (cl-letf (((symbol-function 'read-number)
                   (lambda (_prompt) 10))
                  ((symbol-function 'increamemo-time-today)
                   (lambda () "2026-04-21"))
                  ((symbol-function 'increamemo-time-now)
                   (lambda () "2026-04-21T08:00:00+00:00"))
                  ((symbol-function 'message)
                   (lambda (&rest _args) nil)))
          (increamemo-add-current)
          (increamemo-add-current)
          (should (= 1
                     (increamemo-test-support-count-rows
                      increamemo-db-file
                      "SELECT COUNT(*) FROM increamemo_items")))
          (should (= 1
                     (increamemo-test-support-count-rows
                      increamemo-db-file
                      "SELECT COUNT(*) FROM increamemo_history"))))))))

(provide 'increamemo-add-current-test)
;;; increamemo-add-current-test.el ends here
