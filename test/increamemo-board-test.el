;;; increamemo-board-test.el --- Board tests  -*- lexical-binding: t; -*-

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

;; Regression tests for the board runtime.

;;; Code:

(require 'ert)
(require 'increamemo)
(require 'increamemo-board)
(require 'increamemo-domain)
(require 'increamemo-test-support)

(defun increamemo-board-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :path path
        :title-snapshot (file-name-nondirectory path)))

(defun increamemo-board-test--write-note (root name)
  "Create note NAME under ROOT and return its absolute path."
  (let ((path (expand-file-name name root)))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert name))
    path))

(defun increamemo-board-test--entry-labels (entries)
  "Return the title column from ENTRIES."
  (mapcar (lambda (entry) (aref (cadr entry) 4)) entries))

(defun increamemo-board-test--goto-entry (title)
  "Move point to the row whose title column matches TITLE."
  (goto-char (point-min))
  (search-forward title)
  (beginning-of-line))

(defun increamemo-board-test--setup-items (root)
  "Create planned, due, invalid, and archived items under ROOT."
  (let* ((planned-path (increamemo-board-test--write-note root "notes/planned.md"))
         (due-path (increamemo-board-test--write-note root "notes/due.md"))
         (invalid-path (increamemo-board-test--write-note root "notes/invalid.md"))
         (archived-path (increamemo-board-test--write-note root "notes/archived.md"))
         (invalid-item nil)
         (archived-item nil))
    (increamemo-domain-ensure-item
     (increamemo-board-test--source-ref planned-path)
     30
     "2026-04-25"
     "2026-04-21T08:00:00+00:00")
    (increamemo-domain-ensure-item
     (increamemo-board-test--source-ref due-path)
     10
     "2026-04-21"
     "2026-04-21T08:01:00+00:00")
    (setq invalid-item
          (increamemo-domain-ensure-item
           (increamemo-board-test--source-ref invalid-path)
           20
           "2026-04-21"
           "2026-04-21T08:02:00+00:00"))
    (increamemo-domain-mark-invalid
     (plist-get invalid-item :id)
     "broken"
     "2026-04-21T09:00:00+00:00")
    (setq archived-item
          (increamemo-domain-ensure-item
           (increamemo-board-test--source-ref archived-path)
           40
           "2026-04-21"
           "2026-04-21T08:03:00+00:00"))
    (increamemo-domain-archive-item
     (plist-get archived-item :id)
     "2026-04-21T09:01:00+00:00")))

(ert-deftest increamemo-board-open-renders-planned-items-by-default ()
  "Board opens with planned active items by default."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (should (eq major-mode 'increamemo-board-mode))
                      (should (eq increamemo-board--filter 'planned))
                      (should (equal (sort (increamemo-board-test--entry-labels tabulated-list-entries)
                                           #'string<)
                                     '("due.md" "planned.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-filter-due-shows-only-due-items ()
  "Due filter keeps only due active items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-due)
                      (should (eq increamemo-board--filter 'due))
                      (should (equal (increamemo-board-test--entry-labels tabulated-list-entries)
                                     '("due.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-show-due-toggles-back-to-all-items ()
  "Due toggle returns to all items when invoked from the due filter."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-due)
                      (should (eq increamemo-board--filter 'due))
                      (increamemo-board-show-due)
                      (should (eq increamemo-board--filter 'all))
                      (should (equal (sort (increamemo-board-test--entry-labels
                                            tabulated-list-entries)
                                           #'string<)
                                     '("archived.md"
                                       "due.md"
                                       "invalid.md"
                                       "planned.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-filter-invalid-shows-invalid-items ()
  "Invalid filter keeps only invalid items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-invalid)
                      (should (eq increamemo-board--filter 'invalid))
                      (should (equal (increamemo-board-test--entry-labels tabulated-list-entries)
                                     '("invalid.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-filter-all-shows-active-invalid-and-archived-items ()
  "All filter includes active, invalid, and archived items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-all)
                      (should (eq increamemo-board--filter 'all))
                      (should (equal (sort (increamemo-board-test--entry-labels
                                            tabulated-list-entries)
                                           #'string<)
                                     '("archived.md"
                                       "due.md"
                                       "invalid.md"
                                       "planned.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-open-current-item-opens-selected-row ()
  "Opening the current board row opens the selected item."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-due)
                      (goto-char (point-min))
                      (search-forward "due.md")
                      (beginning-of-line)
                      (let ((opened-buffer (increamemo-board-open-current-item)))
                        (unwind-protect
                            (should (string-match-p "due.md"
                                                    (buffer-file-name opened-buffer)))
                          (when (buffer-live-p opened-buffer)
                            (kill-buffer opened-buffer)))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-quit-kills-board-buffer ()
  "Quitting the board closes its buffer."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (with-current-buffer buffer
                  (increamemo-board-quit))
                (should-not (buffer-live-p buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-actions-update-items-and-refresh-entries ()
  "Board row actions update persistent state and refresh the table."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda () "2026-04-21T09:00:00+00:00")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-test--goto-entry "planned.md")
                      (cl-letf (((symbol-function 'read-string)
                                 (lambda (prompt &rest _args)
                                   (should (equal prompt "Due date (YYYY-MM-DD): "))
                                   "2026-04-19")))
                        (increamemo-board-update-current-due-date))
                      (increamemo-board-show-due)
                      (should (equal (increamemo-board-test--entry-labels
                                      tabulated-list-entries)
                                     '("due.md" "planned.md")))
                      (increamemo-board-show-invalid)
                      (increamemo-board-show-planned)
                      (increamemo-board-test--goto-entry "planned.md")
                      (cl-letf (((symbol-function 'read-number)
                                 (lambda (prompt &rest _args)
                                   (should (equal prompt "Priority (0-100): "))
                                   5)))
                        (increamemo-board-update-current-priority))
                      (should (equal (car (increamemo-board-test--entry-labels
                                           tabulated-list-entries))
                                     "planned.md"))
                      (increamemo-board-test--goto-entry "due.md")
                      (increamemo-board-archive-current-item)
                      (should-not (member "due.md"
                                          (increamemo-board-test--entry-labels
                                           tabulated-list-entries))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))
    (should
      (equal
       (increamemo-test-support-select-row
        increamemo-db-file
        (concat
         "SELECT next_due_date, priority, state "
         "FROM increamemo_items WHERE title_snapshot = ?")
       '("planned.md"))
      '("2026-04-19" 5 "active")))))

(ert-deftest increamemo-board-allows-updating-archived-item-due-date-in-all-view ()
  "Archived rows can update due date from the all-items board view."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda () "2026-04-21T09:00:00+00:00")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-all)
                      (increamemo-board-test--goto-entry "archived.md")
                      (cl-letf (((symbol-function 'read-string)
                                 (lambda (prompt &rest _args)
                                   (should (equal prompt "Due date (YYYY-MM-DD): "))
                                   "2026-04-30")))
                        (increamemo-board-update-current-due-date)))
                  (kill-buffer buffer)))))
        (delete-directory root t)))
    (should
     (equal
      (increamemo-test-support-select-row
       increamemo-db-file
       "SELECT next_due_date, state FROM increamemo_items WHERE title_snapshot = ?"
       '("archived.md"))
      '("2026-04-30" "archived")))))

(ert-deftest increamemo-board-add-item-prompts-and-refreshes ()
  "Adding an item from the board persists it and refreshes the listing."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((root (make-temp-file "increamemo-board-" t))
           (manual-path (increamemo-board-test--write-note root "notes/manual.md"))
           (manual-relative-path "notes/manual.md")
           (seen-type-collection nil)
           (step 0))
      (unwind-protect
          (let ((default-directory root))
            (cl-letf (((symbol-function 'completing-read)
                      (lambda (prompt collection &rest _args)
                         (setq step (1+ step))
                         (should (= step 3))
                         (should (equal prompt "Type: "))
                         (setq seen-type-collection collection)
                         "file"))
                      ((symbol-function 'read-file-name)
                       (lambda (prompt &rest _args)
                         (setq step (1+ step))
                         (should (= step 4))
                         (should (equal prompt "File path: "))
                         manual-relative-path))
                      ((symbol-function 'read-string)
                       (lambda (prompt &optional _history _default _initial-input)
                         (setq step (1+ step))
                         (cond
                          ((equal prompt "Due date (YYYY-MM-DD): ")
                           (should (= step 2))
                           "2026-04-23")
                          (t
                           (ert-fail
                            (format "Unexpected prompt: %S" prompt))))))
                      ((symbol-function 'read-number)
                       (lambda (prompt &rest _args)
                         (setq step (1+ step))
                         (should (= step 1))
                         (should (equal prompt "Priority (0-100): "))
                         15))
                      ((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda () "2026-04-21T09:00:00+00:00")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-add-item)
                      (should (equal (increamemo-board-test--entry-labels
                                      tabulated-list-entries)
                                     '("manual.md"))))
                  (kill-buffer buffer)))))
        (should (equal seen-type-collection '("file" "ekg")))
        (delete-directory root t))
      (should
       (equal
        (increamemo-test-support-select-row
         increamemo-db-file
         (concat
          "SELECT i.type, f.path, i.next_due_date, i.priority "
          "FROM increamemo_items i "
          "JOIN increamemo_file_items f ON f.item_id = i.id "
          "WHERE i.title_snapshot = ?")
         '("manual.md"))
        (list "file" manual-path "2026-04-23" 15))))))

(ert-deftest increamemo-board-stale-row-action-messages-and-refreshes ()
  "Board actions on deleted rows show a message and refresh the listing."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t))
          (captured-message nil))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
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
                      (increamemo-board-test--goto-entry "planned.md")
                      (let* ((item (increamemo-board--current-item-required))
                             (item-id (plist-get item :id)))
                        (increamemo-domain-delete-item
                         item-id
                         "2026-04-21T09:01:00+00:00")
                        (increamemo-board-archive-current-item)
                        (should
                         (equal captured-message
                                (format "Increamemo: item %s does not exist"
                                        item-id)))
                        (should-not
                         (member "planned.md"
                                 (increamemo-board-test--entry-labels
                                  tabulated-list-entries)))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-stale-row-open-messages-and-refreshes ()
  "Opening a deleted row shows a message and refreshes instead of opening."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t))
          (captured-message nil))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'message)
                       (lambda (format-string &rest args)
                         (setq captured-message
                               (apply #'format format-string args)))))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-test--goto-entry "planned.md")
                      (let* ((item (increamemo-board--current-item-required))
                             (item-id (plist-get item :id))
                             (result nil))
                        (increamemo-domain-delete-item
                         item-id
                         "2026-04-21T09:01:00+00:00")
                        (setq result (increamemo-board-open-current-item))
                        (should-not result)
                        (should
                         (equal captured-message
                                (format "Increamemo: item %s does not exist"
                                        item-id)))
                        (should-not
                         (member "planned.md"
                                 (increamemo-board-test--entry-labels
                                  tabulated-list-entries)))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(provide 'increamemo-board-test)
;;; increamemo-board-test.el ends here
