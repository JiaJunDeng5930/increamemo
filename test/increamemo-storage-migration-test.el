;;; increamemo-storage-migration-test.el --- Storage and migration tests  -*- lexical-binding: t; -*-

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

;; Regression tests for storage transactions and schema migration.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-storage)
(require 'increamemo-test-support)

(ert-deftest increamemo-storage-open-requires-sqlite-support ()
  "Opening storage fails fast when this Emacs lacks SQLite support."
  (cl-letf (((symbol-function 'sqlite-available-p)
             (lambda () nil)))
    (should-error
     (increamemo-storage-open "/tmp/increamemo.sqlite")
     :type 'user-error)))

(ert-deftest increamemo-storage-with-transaction-rolls-back-on-error ()
  "Transactions leave no committed rows when the body errors."
  (increamemo-test-support-with-temp-db
    (let ((connection (increamemo-storage-open increamemo-db-file)))
      (unwind-protect
          (progn
            (increamemo-storage-execute
             connection
             "CREATE TABLE entries (value TEXT NOT NULL)")
            (should-error
             (increamemo-storage-with-transaction connection
               (increamemo-storage-execute
                connection
                "INSERT INTO entries(value) VALUES(?)"
                '("kept-out"))
               (error "boom"))
             :type 'error)
            (should-not
             (increamemo-storage-select-value
              connection
              "SELECT value FROM entries LIMIT 1")))
        (increamemo-storage-close connection)))))

(ert-deftest increamemo-init-rejects-outdated-schema-version ()
  "Initialization rejects outdated schemas that require a fresh database."
  (increamemo-test-support-with-temp-db
    (let ((connection (increamemo-storage-open increamemo-db-file)))
      (unwind-protect
          (progn
            (increamemo-storage-execute
             connection
             "CREATE TABLE increamemo_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )")
            (increamemo-storage-execute
             connection
             "INSERT INTO increamemo_meta(key, value) VALUES(?, ?)"
             '("schema-version" "1")))
        (increamemo-storage-close connection)))
    (should-error (increamemo-init) :type 'user-error)))

(ert-deftest increamemo-init-rejects-newer-schema-version ()
  "Initialization stops when the database schema is newer than supported."
  (increamemo-test-support-with-temp-db
    (let ((connection (increamemo-storage-open increamemo-db-file)))
      (unwind-protect
          (progn
            (increamemo-storage-execute
             connection
             "CREATE TABLE increamemo_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )")
            (increamemo-storage-execute
             connection
             "INSERT INTO increamemo_meta(key, value) VALUES(?, ?)"
             '("schema-version" "99")))
        (increamemo-storage-close connection)))
    (should-error (increamemo-init) :type 'user-error)))

(provide 'increamemo-storage-migration-test)
;;; increamemo-storage-migration-test.el ends here
