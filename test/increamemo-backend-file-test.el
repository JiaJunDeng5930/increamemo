;;; increamemo-backend-file-test.el --- File backend tests  -*- lexical-binding: t; -*-

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

;; Regression tests for file backend recognition.

;;; Code:

(require 'ert)
(require 'increamemo)
(require 'increamemo-backend)
(require 'increamemo-storage)

(defmacro increamemo-backend-file-test-with-file-buffer
    (filename contents &rest body)
  "Run BODY with a visiting buffer for FILENAME containing CONTENTS."
  (declare (indent 2) (debug (form form body)))
  `(let* ((temp-dir (make-temp-file "increamemo-backend-file-" t))
          (file-path (expand-file-name ,filename temp-dir)))
     (unwind-protect
         (progn
           (make-directory (file-name-directory file-path) t)
           (with-temp-file file-path
             (insert ,contents))
           (let ((buffer (find-file-noselect file-path)))
             (unwind-protect
                 (with-current-buffer buffer
                   ,@body)
               (when (buffer-live-p buffer)
                 (kill-buffer buffer)))))
       (delete-directory temp-dir t))))

(ert-deftest increamemo-file-backend-builds-item-spec-for-supported-file ()
  "The file backend normalizes supported file buffers into item specs."
  (let ((increamemo-supported-file-formats '("md" "org"))
        (increamemo-file-openers '(("md" . find-file)
                                   ("org" . find-file-other-window))))
    (increamemo-backend-file-test-with-file-buffer "notes/topic.md" "# title"
      (let ((item-spec (increamemo-file-backend-source-ref (current-buffer))))
        (should (equal (plist-get item-spec :type) "file"))
        (should (equal (plist-get item-spec :path)
                       (expand-file-name buffer-file-name)))
        (should (equal (plist-get item-spec :title-snapshot)
                       "topic.md"))))))

(ert-deftest increamemo-file-backend-rejects-unsupported-extensions ()
  "The file backend rejects buffers whose extension is not supported."
  (let ((increamemo-supported-file-formats '("org")))
    (increamemo-backend-file-test-with-file-buffer "notes/topic.md" "# title"
      (should-error
       (increamemo-file-backend-source-ref (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-file-backend-rejects-missing-files ()
  "The file backend requires the visited file to exist."
  (let ((increamemo-supported-file-formats '("md")))
    (with-temp-buffer
      (set-visited-file-name "/tmp/increamemo-missing-note.md" t)
      (should-error
       (increamemo-file-backend-source-ref (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-backend-identify-current-uses-configured-backends ()
  "The backend registry selects the first configured backend that resolves."
  (let ((increamemo-supported-file-formats '("md"))
        (increamemo-file-openers '(("md" . find-file)))
        (increamemo-backends '(increamemo-file-backend)))
    (increamemo-backend-file-test-with-file-buffer "notes/topic.md" "# title"
      (let ((item-spec
             (increamemo-backend-identify-current (current-buffer))))
        (should (equal (plist-get item-spec :type) "file"))
        (should (equal (plist-get item-spec :path)
                       (expand-file-name buffer-file-name)))))))

(ert-deftest increamemo-backend-identify-current-rejects-unknown-backend ()
  "The backend registry raises an error for unknown backend symbols."
  (let ((increamemo-backends '(missing-backend)))
    (with-temp-buffer
      (should-error
       (increamemo-backend-identify-current (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-backend-registry-supports-custom-backends ()
  "Configured backends follow the registry naming contract."
  (let ((increamemo-backends '(increamemo-test-backend)))
    (cl-letf (((symbol-function 'increamemo-test-backend-type)
               (lambda () "test"))
              ((symbol-function 'increamemo-test-backend-recognize-current)
               (lambda (_buffer)
                 '(:type "test" :title-snapshot "Current" :value "current")))
              ((symbol-function 'increamemo-test-backend-build-source-ref)
               (lambda (_type locator &optional _opener)
                 (list :type "test" :title-snapshot "Manual" :value locator))))
      (with-temp-buffer
        (let ((identified
               (increamemo-backend-identify-current (current-buffer)))
              (manual
               (increamemo-backend-build-source-ref "test" "manual")))
          (should (equal (plist-get identified :value) "current"))
          (should (equal (plist-get manual :value) "manual")))))))

(ert-deftest increamemo-backend-build-source-ref-normalizes-manual-file-entry ()
  "The backend registry builds file item specs for manual entry."
  (let ((increamemo-supported-file-formats '("md"))
        (increamemo-file-openers '(("md" . find-file))))
    (let* ((temp-dir (make-temp-file "increamemo-backend-file-manual-" t))
           (default-directory temp-dir)
           (relative-path "notes/manual.md")
           (absolute-path (expand-file-name relative-path temp-dir)))
      (unwind-protect
          (progn
            (make-directory (file-name-directory absolute-path) t)
            (with-temp-file absolute-path
              (insert "# manual"))
            (let ((item-spec
                   (increamemo-backend-build-source-ref "file" relative-path)))
              (should (equal (plist-get item-spec :type) "file"))
              (should (equal (plist-get item-spec :path) absolute-path))
              (should (equal (plist-get item-spec :title-snapshot)
                             "manual.md"))))
        (delete-directory temp-dir t)))))

(ert-deftest increamemo-file-backend-persists-and-hydrates-subtype-data ()
  "The file backend can persist and hydrate its subtype data."
  (let ((increamemo-supported-file-formats '("md"))
        (increamemo-file-openers '(("md" . find-file))))
    (let* ((temp-dir (make-temp-file "increamemo-backend-file-hydrate-" t))
           (path (expand-file-name "notes/manual.md" temp-dir))
           (db-file (make-temp-file "increamemo-backend-file-db-" nil ".sqlite")))
      (unwind-protect
          (progn
            (make-directory (file-name-directory path) t)
            (with-temp-file path
              (insert "# manual"))
            (let ((item-spec (increamemo-file-backend-build-source-ref "file" path))
                  (connection (increamemo-storage-open db-file)))
              (unwind-protect
                  (progn
                    (increamemo-storage-execute
                     connection
                     "CREATE TABLE increamemo_items (id INTEGER PRIMARY KEY, type TEXT NOT NULL, title_snapshot TEXT, next_due_date TEXT NOT NULL, priority INTEGER NOT NULL, state TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, last_reviewed_at TEXT, last_error TEXT, version INTEGER NOT NULL DEFAULT 0)")
                    (increamemo-storage-execute
                     connection
                     "CREATE TABLE increamemo_file_items (item_id INTEGER PRIMARY KEY, path TEXT NOT NULL)")
                    (increamemo-storage-execute
                     connection
                     "INSERT INTO increamemo_items(id, type, title_snapshot, next_due_date, priority, state, created_at, updated_at, version) VALUES(1, 'file', 'manual.md', '2026-04-21', 10, 'active', '2026-04-21T08:00:00+00:00', '2026-04-21T08:00:00+00:00', 0)")
                    (increamemo-file-backend-insert-item-data connection 1 item-spec)
                    (let ((hydrated
                           (increamemo-file-backend-hydrate-item
                            connection
                            '(:id 1 :type "file" :title-snapshot "manual.md"))))
                      (should (equal (plist-get hydrated :path) path))
                      (should (= (increamemo-file-backend-find-live-duplicate-id
                                  connection
                                  item-spec)
                                 1))))
                (increamemo-storage-close connection))))
        (when (file-exists-p db-file)
          (delete-file db-file))
        (delete-directory temp-dir t)))))

(provide 'increamemo-backend-file-test)
;;; increamemo-backend-file-test.el ends here
