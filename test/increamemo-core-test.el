;;; increamemo-core-test.el --- Core tests for increamemo  -*- lexical-binding: t; -*-

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
                       increamemo-board
                       increamemo-earliest-due-distance
                       increamemo-shift-all-due-dates))
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
    (cl-letf (((symbol-function 'completing-read)
               (lambda (&rest _args)
                 (setq prompted t)
                 "ignored"))
              ((symbol-function 'read-file-name)
               (lambda (&rest _args)
                 (setq prompted t)
                 "ignored"))
              ((symbol-function 'read-string)
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
      (should-error (increamemo-earliest-due-distance) :type 'user-error)
      (should-error (increamemo-shift-all-due-dates 1) :type 'user-error)
      (should-not (file-exists-p increamemo-db-file)))))

(ert-deftest increamemo-public-due-commands-report-and-shift-due-dates ()
  "Public due commands report the earliest distance and shift all due dates."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-domain-ensure-item
     (list :type "file"
           :path "/tmp/notes/public-one.md"
           :title-snapshot "public-one.md")
     15
     "2026-04-22"
     "2026-04-21T08:00:00+00:00")
    (increamemo-domain-ensure-item
     (list :type "file"
           :path "/tmp/notes/public-two.md"
           :title-snapshot "public-two.md")
     20
     "2026-04-25"
     "2026-04-21T08:01:00+00:00")
    (cl-letf (((symbol-function 'increamemo-time-today)
               (lambda (&optional _time-value) "2026-04-24"))
              ((symbol-function 'message)
               (lambda (&rest _args) nil)))
      (let ((distance (increamemo-earliest-due-distance)))
        (should (equal (plist-get distance :earliest-due-date) "2026-04-22"))
        (should (= (plist-get distance :days) -2)))
      (let ((shifted (increamemo-shift-all-due-dates 2)))
        (should (= (plist-get shifted :updated-count) 2))
        (should
         (equal
          (increamemo-test-support-select-row
           increamemo-db-file
           (concat
            "SELECT group_concat(next_due_date, ',') "
            "FROM (SELECT next_due_date FROM increamemo_items "
            "ORDER BY next_due_date ASC)"))
          '("2026-04-24,2026-04-27")))))))

(ert-deftest increamemo-board-open-gates-before-creating-buffer ()
  "Board runtime open checks gates before creating the board buffer."
  (let ((increamemo-db-file nil))
    (when (get-buffer increamemo-board-buffer-name)
      (kill-buffer increamemo-board-buffer-name))
    (should-error (increamemo-board-open) :type 'user-error)
    (should-not (get-buffer increamemo-board-buffer-name))))

(ert-deftest increamemo-board-filter-commands-gate-before-state-mutation ()
  "Board filter commands keep the current filter unchanged when gating fails."
  (let ((increamemo-db-file nil))
    (with-temp-buffer
      (increamemo-board-mode)
      (setq-local increamemo-board--filter 'planned)
      (should-error (increamemo-board-show-due) :type 'user-error)
      (should (eq increamemo-board--filter 'planned))
      (should-error (increamemo-board-show-invalid) :type 'user-error)
      (should (eq increamemo-board--filter 'planned))
      (should-error (increamemo-board-show-all) :type 'user-error)
      (should (eq increamemo-board--filter 'planned)))))

(ert-deftest increamemo-board-quit-works-without-config ()
  "Board quit remains available because it only cleans up UI state."
  (let ((increamemo-db-file nil))
    (let ((buffer (get-buffer-create "*Increamemo Board Test*")))
      (unwind-protect
          (with-current-buffer buffer
            (increamemo-board-mode)
            (switch-to-buffer buffer)
            (increamemo-board-quit)
            (should-not (buffer-live-p buffer)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(provide 'increamemo-core-test)
;;; increamemo-core-test.el ends here
