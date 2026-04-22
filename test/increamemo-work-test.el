;;; increamemo-work-test.el --- Work session tests  -*- lexical-binding: t; -*-

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

;; Regression tests for the work session runtime.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-domain)
(require 'increamemo-test-support)
(require 'increamemo-work)

(defun increamemo-work-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :locator path
        :opener 'find-file
        :title-snapshot (file-name-nondirectory path)))

(defun increamemo-work-test--write-note (root name contents)
  "Create NAME under ROOT with CONTENTS and return its absolute path."
  (let ((path (expand-file-name name root)))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert contents))
    path))

(ert-deftest increamemo-work-start-opens-first-due-item-and-enables-mode ()
  "Starting work opens the first due item and enables work mode."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-test-support-with-file-buffer "notes/low.md" "low"
      (let ((low-path (expand-file-name buffer-file-name)))
        (increamemo-domain-ensure-item
         (increamemo-work-test--source-ref low-path)
         50
         "2026-04-21"
         "2026-04-21T08:00:00+00:00")))
    (increamemo-test-support-with-file-buffer "notes/high.md" "high"
      (let* ((high-path (expand-file-name buffer-file-name))
             (high-item
              (increamemo-domain-ensure-item
               (increamemo-work-test--source-ref high-path)
               10
               "2026-04-21"
               "2026-04-21T08:01:00+00:00")))
        (cl-letf (((symbol-function 'increamemo-time-today)
                   (lambda () "2026-04-21")))
          (let ((opened-buffer (increamemo-work-start)))
            (unwind-protect
                (with-current-buffer opened-buffer
                  (should increamemo-work-mode)
                  (should (= increamemo-work--current-item-id
                             (plist-get high-item :id)))
                  (should (equal (buffer-file-name)
                                 high-path))
                  (should (equal (increamemo-work--mode-line-text)
                                 "IM[0/2]")))
              (increamemo-work-quit)
              (when (buffer-live-p opened-buffer)
                (kill-buffer opened-buffer)))))))))

(ert-deftest increamemo-work-start-shows-message-when-no-due-items ()
  "Starting work shows a message and does not keep a session when nothing is due."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((captured-message nil))
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21"))
                ((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (setq captured-message
                         (apply #'format format-string args)))))
        (should-not (increamemo-work-start))
        (should (equal captured-message "Increamemo: no due items"))
        (should-not increamemo-work--session)))))

(ert-deftest increamemo-work-quit-clears-session-state ()
  "Quitting work disables the mode and clears the active session."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-test-support-with-file-buffer "notes/topic.md" "topic"
      (let ((path (expand-file-name buffer-file-name)))
        (increamemo-domain-ensure-item
         (increamemo-work-test--source-ref path)
         10
         "2026-04-21"
         "2026-04-21T08:00:00+00:00"))
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21")))
        (let ((opened-buffer (increamemo-work-start)))
          (with-current-buffer opened-buffer
            (increamemo-work-quit)
            (should-not increamemo-work-mode)
            (should-not increamemo-work--current-item-id)
            (should-not increamemo-work--session-id))
          (should-not increamemo-work--session)
          (when (buffer-live-p opened-buffer)
            (kill-buffer opened-buffer)))))))

(ert-deftest increamemo-work-quit-cleans-up-without-config ()
  "Work quit remains available because it only clears runtime state."
  (let ((increamemo-db-file "/tmp/increamemo.sqlite"))
    (with-temp-buffer
      (setq increamemo-work--session
            (make-increamemo-session
             :id 1
             :date "2026-04-21"
             :handled-count 0
             :excluded-item-ids nil
             :current-item-id 7
             :active-p t))
      (setq-local increamemo-work--current-item-id 7)
      (setq-local increamemo-work--session-id 1)
      (increamemo-work-mode 1)
      (let ((increamemo-db-file nil))
        (increamemo-work-quit))
      (should-not increamemo-work-mode)
      (should-not increamemo-work--current-item-id)
      (should-not increamemo-work--session-id)
      (should-not increamemo-work--session))))

(ert-deftest increamemo-work-archive-archives-current-item-and-opens-next-item ()
  "Archiving the current work item advances to the next due item."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-work-" t)))
      (unwind-protect
          (let* ((archive-path
                  (increamemo-work-test--write-note
                   root
                   "notes/archive.md"
                   "archive"))
                 (next-path
                  (increamemo-work-test--write-note
                   root
                   "notes/next.md"
                   "next")))
            (increamemo-domain-ensure-item
             (increamemo-work-test--source-ref archive-path)
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00")
          (increamemo-domain-ensure-item
           (increamemo-work-test--source-ref next-path)
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
                    (let ((next-buffer (increamemo-work-archive)))
                      (unwind-protect
                          (progn
                            (should (equal (buffer-file-name next-buffer) next-path))
                            (should (= (increamemo-session-handled-count
                                        increamemo-work--session)
                                       1))
                            (should
                             (equal
                              (car
                               (increamemo-test-support-select-row
                                increamemo-db-file
                                "SELECT state FROM increamemo_items WHERE locator = ?"
                                (list archive-path)))
                              "archived")))
                        (when (buffer-live-p next-buffer)
                          (with-current-buffer next-buffer
                            (increamemo-work-quit))
                          (kill-buffer next-buffer)))))
                (when (buffer-live-p opened-buffer)
                  (kill-buffer opened-buffer))))))
        (delete-directory root t)))))

(ert-deftest increamemo-work-defer-accepts-day-offset-and-opens-next-item ()
  "Deferring accepts a day offset and advances the session."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-work-" t)))
      (unwind-protect
          (let* ((defer-path
                  (increamemo-work-test--write-note
                   root
                   "notes/defer.md"
                   "defer"))
                 (next-path
                  (increamemo-work-test--write-note
                   root
                   "notes/next.md"
                   "next")))
            (increamemo-domain-ensure-item
             (increamemo-work-test--source-ref defer-path)
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00")
          (increamemo-domain-ensure-item
           (increamemo-work-test--source-ref next-path)
           20
           "2026-04-21"
           "2026-04-21T08:01:00+00:00")
          (cl-letf (((symbol-function 'increamemo-time-today)
                     (lambda () "2026-04-21"))
                    ((symbol-function 'increamemo-time-now)
                     (lambda () "2026-04-21T09:00:00+00:00"))
                    ((symbol-function 'read-string)
                     (lambda (prompt &rest _args)
                       (should
                        (equal prompt
                               "Defer to date (YYYY-MM-DD) or +days: "))
                       "3")))
            (let ((opened-buffer (increamemo-work-start)))
              (unwind-protect
                  (with-current-buffer opened-buffer
                    (let ((next-buffer (increamemo-work-defer)))
                      (unwind-protect
                          (progn
                            (should (equal (buffer-file-name next-buffer) next-path))
                            (should (= (increamemo-session-handled-count
                                        increamemo-work--session)
                                       1))
                            (should
                             (equal
                              (car
                               (increamemo-test-support-select-row
                                increamemo-db-file
                                "SELECT next_due_date FROM increamemo_items WHERE locator = ?"
                                (list defer-path)))
                              "2026-04-24")))
                        (when (buffer-live-p next-buffer)
                          (with-current-buffer next-buffer
                            (increamemo-work-quit))
                          (kill-buffer next-buffer)))))
                (when (buffer-live-p opened-buffer)
                  (kill-buffer opened-buffer))))))
        (delete-directory root t)))))

(ert-deftest increamemo-work-skip-excludes-item-only-for-current-session ()
  "Skipping records history and only hides the item for the active session."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-work-" t)))
      (unwind-protect
          (let* ((skip-path
                  (increamemo-work-test--write-note
                   root
                   "notes/skip.md"
                   "skip"))
                 (next-path
                  (increamemo-work-test--write-note
                   root
                   "notes/next.md"
                   "next")))
            (increamemo-domain-ensure-item
             (increamemo-work-test--source-ref skip-path)
             10
             "2026-04-21"
             "2026-04-21T08:00:00+00:00")
          (increamemo-domain-ensure-item
           (increamemo-work-test--source-ref next-path)
           20
           "2026-04-21"
           "2026-04-21T08:01:00+00:00")
          (cl-letf (((symbol-function 'increamemo-time-today)
                     (lambda () "2026-04-21"))
                    ((symbol-function 'increamemo-time-now)
                     (lambda () "2026-04-21T09:00:00+00:00")))
            (let ((opened-buffer (increamemo-work-start))
                  (reopened-buffer nil))
              (unwind-protect
                  (with-current-buffer opened-buffer
                    (let ((next-buffer (increamemo-work-skip)))
                      (setq reopened-buffer next-buffer)
                      (should (equal (buffer-file-name next-buffer) next-path))
                      (should (= (increamemo-session-handled-count
                                  increamemo-work--session)
                                 1))
                      (should
                       (equal
                        (car
                         (increamemo-test-support-select-row
                          increamemo-db-file
                          "SELECT state FROM increamemo_items WHERE locator = ?"
                          (list skip-path)))
                        "active"))
                      (should (= 1
                                 (increamemo-test-support-count-rows
                                  increamemo-db-file
                                  (concat
                                   "SELECT COUNT(*) FROM increamemo_history "
                                   "WHERE item_id = ? AND action = 'skipped'")
                                  (list
                                   (car
                                    (increamemo-test-support-select-row
                                     increamemo-db-file
                                     "SELECT id FROM increamemo_items WHERE locator = ?"
                                     (list skip-path)))))))
                      (with-current-buffer next-buffer
                        (increamemo-work-quit))
                      (kill-buffer next-buffer)
                      (setq reopened-buffer nil)
                      (setq opened-buffer (increamemo-work-start))
                      (should (equal (buffer-file-name opened-buffer) skip-path))
                      (with-current-buffer opened-buffer
                        (increamemo-work-quit))))
                (when (buffer-live-p reopened-buffer)
                  (kill-buffer reopened-buffer))
                (when (buffer-live-p opened-buffer)
                  (kill-buffer opened-buffer))))))
        (delete-directory root t)))))

(ert-deftest increamemo-work-update-priority-updates-current-item-in-place ()
  "Updating priority keeps the current buffer active and refreshes data."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-test-support-with-file-buffer "notes/priority.md" "priority"
      (let ((priority-path (expand-file-name buffer-file-name)))
        (increamemo-domain-ensure-item
         (increamemo-work-test--source-ref priority-path)
         30
         "2026-04-21"
         "2026-04-21T08:00:00+00:00")
        (cl-letf (((symbol-function 'increamemo-time-today)
                   (lambda () "2026-04-21"))
                  ((symbol-function 'increamemo-time-now)
                   (lambda () "2026-04-21T09:00:00+00:00"))
                  ((symbol-function 'read-number)
                   (lambda (prompt &rest _args)
                     (should (equal prompt "Priority (0-100): "))
                     5)))
          (let ((opened-buffer (increamemo-work-start)))
            (unwind-protect
                (with-current-buffer opened-buffer
                  (should (equal (buffer-file-name) priority-path))
                  (increamemo-work-update-priority)
                  (should (equal (buffer-file-name) priority-path))
                  (should (= (increamemo-session-handled-count
                              increamemo-work--session)
                             0))
                  (should
                   (equal
                    (car
                     (increamemo-test-support-select-row
                      increamemo-db-file
                      "SELECT priority FROM increamemo_items WHERE locator = ?"
                      (list priority-path)))
                    5))
                  (increamemo-work-quit))
              (when (buffer-live-p opened-buffer)
                (kill-buffer opened-buffer)))))))))

(ert-deftest increamemo-work-session-progress-restarts-from-current-due-set ()
  "A new work session recomputes progress from the remaining due items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-work-" t))
          (first-buffer nil)
          (second-buffer nil))
      (unwind-protect
          (let* ((first-path
                  (increamemo-work-test--write-note root "notes/first.md" "first"))
                 (second-path
                  (increamemo-work-test--write-note root "notes/second.md" "second"))
                 (third-path
                  (increamemo-work-test--write-note root "notes/third.md" "third"))
                 (time-values '("2026-04-21T08:00:00+00:00"
                                "2026-04-21T08:01:00+00:00"
                                "2026-04-21T08:02:00+00:00"
                                "2026-04-21T09:00:00+00:00"
                                "2026-04-21T09:00:01+00:00")))
            (dolist (item `((,first-path 10)
                            (,second-path 20)
                            (,third-path 30)))
              (increamemo-domain-ensure-item
               (increamemo-work-test--source-ref (car item))
               (cadr item)
               "2026-04-21"
               (pop time-values)))
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda ()
                         (prog1 (car time-values)
                           (setq time-values (cdr time-values)))))
                      ((symbol-function 'message)
                       (lambda (&rest _args) nil))
                      ((symbol-function 'increamemo-reschedule-function)
                       #'ignore))
              (setq increamemo-reschedule-function
                    (lambda (_item _action) "2026-04-28"))
              (setq first-buffer (increamemo-work-start))
              (with-current-buffer first-buffer
                (setq second-buffer (increamemo-work-complete)))
              (with-current-buffer second-buffer
                (should (equal (increamemo-work--mode-line-text) "IM[1/2]"))
                (increamemo-work-quit))
              (kill-buffer second-buffer)
              (setq second-buffer nil)
              (when (buffer-live-p first-buffer)
                (kill-buffer first-buffer)
                (setq first-buffer nil))
              (setq first-buffer (increamemo-work-start))
              (with-current-buffer first-buffer
                (should (equal (buffer-file-name) second-path))
                (should (equal (increamemo-work--mode-line-text) "IM[0/2]"))
                (increamemo-work-quit))))
        (when (buffer-live-p second-buffer)
          (kill-buffer second-buffer))
        (when (buffer-live-p first-buffer)
          (kill-buffer first-buffer))
        (delete-directory root t)))))

(ert-deftest increamemo-work-session-uses-current-date-after-midnight ()
  "An open session re-evaluates due items against the current date."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-work-" t))
          (today-value "2026-04-21")
          (current-buffer nil)
          (next-buffer nil))
      (unwind-protect
          (let* ((first-path
                  (increamemo-work-test--write-note root "notes/first.md" "first"))
                 (second-path
                  (increamemo-work-test--write-note root "notes/second.md" "second"))
                 (time-values '("2026-04-21T08:00:00+00:00"
                                "2026-04-21T08:01:00+00:00"
                                "2026-04-22T00:01:00+00:00"
                                "2026-04-22T00:02:00+00:00")))
            (increamemo-domain-ensure-item
             (increamemo-work-test--source-ref first-path)
             10
             "2026-04-21"
             (pop time-values))
            (increamemo-domain-ensure-item
             (increamemo-work-test--source-ref second-path)
             20
             "2026-04-22"
             (pop time-values))
            (let ((increamemo-reschedule-function
                   (lambda (_item _action _history-summary _today)
                     "2026-04-28")))
              (cl-letf (((symbol-function 'increamemo-time-today)
                         (lambda () today-value))
                        ((symbol-function 'increamemo-time-now)
                         (lambda ()
                           (prog1 (car time-values)
                             (setq time-values (cdr time-values)))))
                        ((symbol-function 'message)
                         (lambda (&rest _args) nil)))
                (setq current-buffer (increamemo-work-start))
                (with-current-buffer current-buffer
                  (should (equal (buffer-file-name) first-path))
                  (should (equal (increamemo-work--mode-line-text) "IM[0/1]")))
                (setq today-value "2026-04-22")
                (with-current-buffer current-buffer
                  (should (equal (increamemo-work--mode-line-text) "IM[0/2]"))
                  (setq next-buffer (increamemo-work-skip)))
                (with-current-buffer next-buffer
                  (should (equal (buffer-file-name) second-path))
                  (should (equal (increamemo-work--mode-line-text) "IM[1/1]"))
                  (should-not (increamemo-work-complete))
                  (should
                   (equal
                    (car
                     (increamemo-test-support-select-row
                      increamemo-db-file
                      "SELECT next_due_date FROM increamemo_items WHERE locator = ?"
                      (list second-path)))
                    "2026-04-28"))))))
        (when (buffer-live-p next-buffer)
          (kill-buffer next-buffer))
        (when (buffer-live-p current-buffer)
          (kill-buffer current-buffer))
        (delete-directory root t)))))

(provide 'increamemo-work-test)
;;; increamemo-work-test.el ends here
