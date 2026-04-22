;;; increamemo-static-test.el --- Static architecture tests  -*- lexical-binding: t; -*-

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

;; Regression tests for repository-wide architectural constraints.

;;; Code:

(require 'ert)
(require 'increamemo-board)
(require 'increamemo-test-support)
(require 'increamemo-work)

(ert-deftest increamemo-static-sqlite-calls-stay-in-storage-layer ()
  "SQLite calls stay inside storage and migration modules."
  (let ((violations nil))
    (dolist (file (increamemo-test-support-project-elisp-files))
      (unless (member (file-name-nondirectory file)
                      '("increamemo-storage.el" "increamemo-migration.el"))
        (let ((case-fold-search nil))
          (when (string-match-p
                 "\\_<sqlite-[[:alnum:]-]+\\_>"
                 (increamemo-test-support-read-file file))
            (push file violations)))))
    (should-not violations)))

(ert-deftest increamemo-static-ekg-symbols-stay-in-ekg-backend ()
  "EKG integration points stay inside the EKG backend implementation."
  (let ((violations nil))
    (dolist (file (increamemo-test-support-project-elisp-files))
      (unless (equal (file-name-nondirectory file) "increamemo-backend-ekg.el")
        (when (string-match-p
               "[^[:alnum:]-]ekg-"
               (concat " " (increamemo-test-support-read-file file)))
          (push file violations))))
    (should-not violations)))

(ert-deftest increamemo-static-work-and-board-do-not-depend-on-migration ()
  "Runtime UI modules keep schema management out of their dependency graph."
  (dolist (file '("increamemo-work.el" "increamemo-board.el"))
    (should-not
     (string-match-p
      "increamemo-migration-"
      (increamemo-test-support-read-file
       (expand-file-name file increamemo-test-support--project-root))))))

(ert-deftest increamemo-static-due-order-clause-has-single-definition ()
  "The canonical due-order clause appears once in the domain implementation."
  (let* ((source
          (increamemo-test-support-read-file
           (expand-file-name
            "increamemo-domain.el"
            increamemo-test-support--project-root)))
         (pattern
          (regexp-quote
           "ORDER BY priority ASC, next_due_date ASC, created_at ASC"))
         (start 0)
         (count 0))
    (while (string-match pattern source start)
      (setq count (1+ count))
      (setq start (match-end 0)))
    (should (= count 1))))

(ert-deftest increamemo-work-keymap-only-activates-in-work-mode ()
  "Work commands are available only while work mode is enabled."
  (with-temp-buffer
    (should-not (key-binding (kbd "C-c , c")))
    (increamemo-work-mode 1)
    (should (eq (key-binding (kbd "C-c , c"))
                #'increamemo-work-complete))
    (increamemo-work-mode -1)
    (should-not (key-binding (kbd "C-c , c")))))

(ert-deftest increamemo-board-keymap-exposes-documented-actions ()
  "Board mode exposes the documented row actions and quit binding."
  (with-temp-buffer
    (increamemo-board-mode)
    (should (eq (key-binding (kbd "a"))
                #'increamemo-board-add-item))
    (should (eq (key-binding (kbd "A"))
                #'increamemo-board-archive-current-item))
    (should (eq (key-binding (kbd "d"))
                #'increamemo-board-update-current-due-date))
    (should (eq (key-binding (kbd "p"))
                #'increamemo-board-update-current-priority))
    (should (eq (key-binding (kbd "t"))
                #'increamemo-board-show-due))
    (should (eq (key-binding (kbd "q"))
                #'increamemo-board-quit))))

(provide 'increamemo-static-test)
;;; increamemo-static-test.el ends here
