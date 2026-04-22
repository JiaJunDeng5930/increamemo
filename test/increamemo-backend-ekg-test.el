;;; increamemo-backend-ekg-test.el --- EKG backend tests  -*- lexical-binding: t; -*-

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

;; Regression tests for the EKG backend.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo-backend-ekg)
(require 'increamemo-storage)

(ert-deftest increamemo-ekg-backend-recognizes-current-note-buffer ()
  "The EKG backend returns an item spec for an EKG note buffer."
  (with-temp-buffer
    (rename-buffer "*ekg topic*" t)
    (setq-local ekg-note '(:id 42))
    (cl-letf (((symbol-function 'ekg-note-id)
               (lambda (note)
                 (plist-get note :id)))
              ((symbol-function 'ekg-get-note-with-id)
               (lambda (_note-id) nil))
              ((symbol-function 'ekg-edit)
               (lambda (_note) nil)))
      (let ((item-spec
             (increamemo-ekg-backend-recognize-current (current-buffer))))
        (should (equal (plist-get item-spec :type) "ekg"))
        (should (equal (plist-get item-spec :note-id) "42"))
        (should (equal (plist-get item-spec :title-snapshot)
                       "*ekg topic*"))))))

(ert-deftest increamemo-ekg-backend-returns-nil-for-non-ekg-buffer ()
  "The EKG backend ignores unrelated buffers."
  (with-temp-buffer
    (should-not
     (increamemo-ekg-backend-recognize-current (current-buffer)))))

(ert-deftest increamemo-ekg-backend-errors-when-ekg-functions-are-missing ()
  "The EKG backend raises an error for EKG buffers without required APIs."
  (with-temp-buffer
    (setq-local ekg-note '(:id 42))
    (should-error
     (increamemo-ekg-backend-recognize-current (current-buffer))
     :type 'user-error)))

(ert-deftest increamemo-ekg-backend-requires-note-id ()
  "The EKG backend requires the current note to provide an identifier."
  (with-temp-buffer
    (setq-local ekg-note '(:id nil))
    (cl-letf (((symbol-function 'ekg-note-id)
               (lambda (_note) nil)))
      (should-error
       (increamemo-ekg-backend-recognize-current (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-ekg-open-note-opens-note-by-id ()
  "The EKG opener wrapper loads and opens the note matching the id."
  (let ((opened-note nil)
        (opened-buffer (generate-new-buffer "*ekg opened*")))
    (unwind-protect
        (cl-letf (((symbol-function 'ekg-get-note-with-id)
                   (lambda (note-id)
                     (should (= note-id 42))
                     '(:id 42 :text "note")))
                  ((symbol-function 'ekg-edit)
                   (lambda (note)
                     (setq opened-note note)
                     opened-buffer)))
          (should (eq (increamemo-ekg-open-note "42")
                      opened-buffer))
          (should (equal opened-note '(:id 42 :text "note"))))
      (kill-buffer opened-buffer))))

(ert-deftest increamemo-ekg-open-note-errors-when-note-is-missing ()
  "The EKG opener wrapper raises an error when no note matches the id."
  (cl-letf (((symbol-function 'ekg-get-note-with-id)
             (lambda (_note-id) nil)))
    (should-error
     (increamemo-ekg-open-note "42")
     :type 'user-error)))

(ert-deftest increamemo-ekg-backend-builds-manual-item-spec ()
  "The EKG backend returns a manual item spec."
  (cl-letf (((symbol-function 'ekg-get-note-with-id)
             (lambda (_note-id) nil))
            ((symbol-function 'ekg-edit)
             (lambda (_note) nil)))
    (let ((item-spec (increamemo-ekg-backend-build-source-ref "ekg" "42")))
      (should (equal (plist-get item-spec :type) "ekg"))
      (should (equal (plist-get item-spec :note-id) "42"))
      (should (equal (plist-get item-spec :title-snapshot) "42")))))

(ert-deftest increamemo-ekg-backend-build-source-ref-validates-note-id ()
  "Manual EKG item specs reject invalid note id syntax."
  (should-error
   (increamemo-ekg-backend-build-source-ref "ekg" "(")
   :type 'user-error))

(ert-deftest increamemo-ekg-backend-build-source-ref-requires-ekg-opening-api ()
  "Manual EKG item specs require the EKG opening functions."
  (should-error
   (increamemo-ekg-backend-build-source-ref "ekg" "42")
   :type 'user-error))

(ert-deftest increamemo-ekg-backend-persists-and-hydrates-subtype-data ()
  "The EKG backend can persist and hydrate its subtype data."
  (cl-letf (((symbol-function 'ekg-get-note-with-id)
             (lambda (_note-id) nil))
            ((symbol-function 'ekg-edit)
             (lambda (_note) nil)))
    (let ((item-spec (increamemo-ekg-backend-build-source-ref "ekg" "42"))
          (db-file (make-temp-file "increamemo-backend-ekg-db-" nil ".sqlite")))
      (unwind-protect
          (let ((connection (increamemo-storage-open db-file)))
            (unwind-protect
                (progn
                  (increamemo-storage-execute
                   connection
                   "CREATE TABLE increamemo_items (id INTEGER PRIMARY KEY, type TEXT NOT NULL, title_snapshot TEXT, next_due_date TEXT NOT NULL, priority INTEGER NOT NULL, state TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, last_reviewed_at TEXT, last_error TEXT, version INTEGER NOT NULL DEFAULT 0, a_factor REAL NOT NULL)")
                  (increamemo-storage-execute
                   connection
                   "CREATE TABLE increamemo_ekg_items (item_id INTEGER PRIMARY KEY, note_id TEXT NOT NULL)")
                  (increamemo-storage-execute
                   connection
                   "INSERT INTO increamemo_items(id, type, title_snapshot, next_due_date, priority, state, created_at, updated_at, version, a_factor) VALUES(1, 'ekg', '42', '2026-04-21', 10, 'active', '2026-04-21T08:00:00+00:00', '2026-04-21T08:00:00+00:00', 0, 1.1)")
                  (increamemo-ekg-backend-insert-item-data connection 1 item-spec)
                  (let ((hydrated
                         (increamemo-ekg-backend-hydrate-item
                          connection
                          '(:id 1 :type "ekg" :title-snapshot "42"))))
                    (should (equal (plist-get hydrated :note-id) "42"))
                    (should (= (increamemo-ekg-backend-find-live-duplicate-id
                                connection
                                item-spec)
                               1))))
              (increamemo-storage-close connection)))
        (delete-file db-file)))))

(provide 'increamemo-backend-ekg-test)
;;; increamemo-backend-ekg-test.el ends here
