;;; increamemo-e2e-test.el --- End-to-end tests  -*- lexical-binding: t; -*-

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

;; End-to-end regression tests for the main user workflow.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-board)
(require 'increamemo-storage)
(require 'increamemo-test-support)
(require 'increamemo-work)

(ert-deftest increamemo-e2e-file-workflow-updates-db-and-board ()
  "The main file workflow updates scheduling state end to end."
  (increamemo-test-support-with-temp-db
    (let ((note-a nil)
          (note-b nil)
          (time-values '("2026-04-21T08:00:00+00:00"
                         "2026-04-21T08:01:00+00:00"
                         "2026-04-21T09:00:00+00:00"
                         "2026-04-21T09:00:01+00:00")))
      (increamemo-test-support-with-file-buffer "notes/a.md" "alpha"
        (setq note-a (expand-file-name buffer-file-name))
        (increamemo-test-support-with-file-buffer "notes/b.md" "beta"
          (setq note-b (expand-file-name buffer-file-name))
          (cl-letf (((symbol-function 'increamemo-time-today)
                     (lambda () "2026-04-21"))
                    ((symbol-function 'increamemo-time-now)
                     (lambda ()
                       (prog1 (car time-values)
                         (setq time-values (cdr time-values)))))
                    ((symbol-function 'message)
                     (lambda (&rest _args) nil)))
            (setq increamemo-supported-file-formats '("md"))
            (setq increamemo-file-openers '(("md" . find-file)))
            (setq increamemo-reschedule-function
                  (lambda (_item _action) "2026-04-28"))
            (increamemo-init)
            (with-current-buffer (find-file-noselect note-a)
              (cl-letf (((symbol-function 'read-number) (lambda (_prompt) 10)))
                (increamemo-add-current)))
            (with-current-buffer (find-file-noselect note-b)
              (cl-letf (((symbol-function 'read-number) (lambda (_prompt) 20)))
                (increamemo-add-current)))
            (should
             (= 2
                (increamemo-test-support-count-rows
                 increamemo-db-file
                 "SELECT COUNT(*) FROM increamemo_items")))
            (let ((work-buffer (increamemo-work-start)))
              (unwind-protect
                  (progn
                    (should (equal (buffer-file-name work-buffer) note-a))
                    (with-current-buffer work-buffer
                      (should (equal (increamemo-work--mode-line-text)
                                     "IM[0/2]"))
                      (let ((next-buffer (increamemo-work-complete)))
                        (unwind-protect
                            (with-current-buffer next-buffer
                              (should (equal (buffer-file-name) note-b))
                              (should (equal (increamemo-work--mode-line-text)
                                             "IM[1/1]"))
                              (increamemo-work-quit))
                          (when (buffer-live-p next-buffer)
                            (kill-buffer next-buffer))))))
                (when (buffer-live-p work-buffer)
                  (kill-buffer work-buffer))))
            (let ((board-buffer (increamemo-board-open)))
              (unwind-protect
                  (with-current-buffer board-buffer
                    (should (equal (sort (mapcar (lambda (entry) (aref (cadr entry)
                                                                        (1- (length (cadr entry)))))
                                                 tabulated-list-entries)
                                         #'string<)
                                   '("a.md" "b.md")))
                    (increamemo-board-show-due)
                    (should (equal (mapcar (lambda (entry) (aref (cadr entry)
                                                                  (1- (length (cadr entry)))))
                                           tabulated-list-entries)
                                   '("b.md"))))
                (kill-buffer board-buffer)))
            (should
             (equal
              (increamemo-test-support-select-row
               increamemo-db-file
               (concat
                "SELECT title_snapshot, next_due_date, state "
                "FROM increamemo_items WHERE title_snapshot = ?")
               '("a.md"))
              '("a.md" "2026-04-28" "active")))
            (should
             (equal
              (increamemo-test-support-select-row
               increamemo-db-file
               (concat
                "SELECT title_snapshot, next_due_date, state "
                "FROM increamemo_items WHERE title_snapshot = ?")
               '("b.md"))
              '("b.md" "2026-04-21" "active")))))))))

(provide 'increamemo-e2e-test)
;;; increamemo-e2e-test.el ends here
