;;; increamemo-failure-test.el --- Failure policy tests  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jiajun Deng

;; Author: Jiajun Deng <3230105930@zju.edu.cn>
;; Maintainer: Jiajun Deng <3230105930@zju.edu.cn>

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Regression tests for open failure handling.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-board)
(require 'increamemo-domain)
(require 'increamemo-opener)
(require 'increamemo-test-support)
(require 'increamemo-work)

(defun increamemo-failure-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :locator path
        :opener 'find-file
        :title-snapshot (file-name-nondirectory path)))

(defvar increamemo-failure-test--delete-during-open-item-id nil
  "Item id deleted by `increamemo-failure-test-delete-and-fail'.")

(defun increamemo-failure-test-delete-and-fail (_locator)
  "Delete the configured item and then signal an opener failure."
  (increamemo-domain-delete-item
   increamemo-failure-test--delete-during-open-item-id
   "2026-04-21T08:59:00+00:00")
  (signal 'increamemo-opener-error
          (list (list :reason 'opener-error
                      :message "Increamemo: opener failed: deleted during open"))))

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
         "SELECT COUNT(*) FROM increamemo_items WHERE state = 'active'")))
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
         "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'deleted'"
         (list broken-id))))))

(ert-deftest increamemo-work-start-delete-policy-treats-missing-row-as-deleted ()
  "Delete policy continues when the failing item is removed during opening."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((increamemo-invalid-opener-policy 'delete)
          (captured-message nil)
          (increamemo-failure-test--delete-during-open-item-id nil))
      (let* ((broken-item
              (increamemo-domain-ensure-item
               (list :type "custom"
                     :locator "delete://broken"
                     :opener 'increamemo-failure-test-delete-and-fail
                     :title-snapshot "broken")
               10
               "2026-04-21"
               "2026-04-21T08:00:00+00:00"))
             (broken-id (plist-get broken-item :id)))
        (setq increamemo-failure-test--delete-during-open-item-id broken-id)
        (increamemo-test-support-with-file-buffer "notes/topic.md" "topic"
          (let ((valid-path (expand-file-name buffer-file-name)))
            (increamemo-domain-ensure-item
             (increamemo-failure-test--source-ref valid-path)
             20
             "2026-04-21"
             "2026-04-21T08:01:00+00:00")
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda () "2026-04-21T09:00:00+00:00"))
                      ((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (setq captured-message
                               (apply #'format format-string args)))))
              (let ((opened-buffer (increamemo-work-start)))
                (unwind-protect
                    (progn
                      (should (equal (buffer-file-name opened-buffer) valid-path))
                      (should (= (increamemo-session-handled-count increamemo-work--session)
                                 1))
                      (should (string-match-p "failed to open item" captured-message))
                      (should
                       (= 0
                          (increamemo-test-support-count-rows
                           increamemo-db-file
                           "SELECT COUNT(*) FROM increamemo_items WHERE id = ?"
                           (list broken-id))))
                      (should
                       (= 0
                          (increamemo-test-support-count-rows
                           increamemo-db-file
                           "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'open_failed'"
                           (list broken-id))))
                      (should
                       (= 1
                          (increamemo-test-support-count-rows
                           increamemo-db-file
                           "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'deleted'"
                           (list broken-id)))))
                  (when (buffer-live-p opened-buffer)
                    (with-current-buffer opened-buffer
                      (increamemo-work-quit))
                    (kill-buffer opened-buffer)))))))))))

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
                     (list (plist-get item :id)))))
                (should
                 (= 1
                    (increamemo-test-support-count-rows
                     increamemo-db-file
                     "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'open_failed'"
                     (list (plist-get item :id)))))
                (should
                 (= 1
                    (increamemo-test-support-count-rows
                     increamemo-db-file
                     "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ? AND action = 'deleted'"
                     (list (plist-get item :id))))))
            (kill-buffer buffer)))))))

(provide 'increamemo-failure-test)
;;; increamemo-failure-test.el ends here
