;;; increamemo-backend-file.el --- File backend for increamemo  -*- lexical-binding: t; -*-

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

;; File-backed source recognition and storage.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-storage)

(defconst increamemo-file-backend 'increamemo-file-backend
  "Symbol used for the file backend.")

(defun increamemo-file-backend-type ()
  "Return the item type string for the file backend."
  "file")

(defun increamemo-file-backend--normalize-path (path)
  "Return the normalized absolute PATH."
  (expand-file-name path))

(defun increamemo-file-backend--file-extension (path)
  "Return the normalized lowercase extension for PATH."
  (downcase (or (file-name-extension path) "")))

(defun increamemo-file-backend--supported-format-p (extension)
  "Return non-nil when EXTENSION is configured as supported."
  (member extension
          (mapcar #'downcase increamemo-supported-file-formats)))

(defun increamemo-file-backend--resolve-opener (path)
  "Return the configured opener for PATH."
  (cdr (assoc-string (increamemo-file-backend--file-extension path)
                     increamemo-file-openers
                     t)))

(defun increamemo-file-backend--validate-path (path)
  "Return PATH normalized for the file backend."
  (let* ((normalized-path (increamemo-file-backend--normalize-path path))
         (extension (increamemo-file-backend--file-extension normalized-path)))
    (unless (file-exists-p normalized-path)
      (user-error "Increamemo: file does not exist: %s" normalized-path))
    (unless (increamemo-file-backend--supported-format-p extension)
      (user-error "Increamemo: unsupported file format: %s" extension))
    (unless (functionp (increamemo-file-backend--resolve-opener normalized-path))
      (user-error
       "Increamemo: no opener configured for extension: %s"
       extension))
    normalized-path))

(defun increamemo-file-backend--build-item-spec (path)
  "Return a file item spec for PATH."
  (let ((normalized-path (increamemo-file-backend--validate-path path)))
    (list :type "file"
          :title-snapshot (file-name-nondirectory normalized-path)
          :path normalized-path)))

(defun increamemo-file-backend-recognize-current (&optional buffer)
  "Return a file item spec for BUFFER, or nil when unrelated."
  (with-current-buffer (or buffer (current-buffer))
    (when-let ((file-name buffer-file-name))
      (increamemo-file-backend--build-item-spec file-name))))

(defun increamemo-file-backend-source-ref (&optional buffer)
  "Return a file item spec for BUFFER or raise `user-error'."
  (or (increamemo-file-backend-recognize-current buffer)
      (user-error "Increamemo: current buffer is not a supported file item")))

(defun increamemo-file-backend-prompt-new-item ()
  "Prompt for a file item and return its item spec."
  (increamemo-file-backend--build-item-spec
   (read-file-name "File path: " nil nil t)))

(defun increamemo-file-backend-build-source-ref (_type locator &optional _opener)
  "Return a file item spec for LOCATOR."
  (increamemo-file-backend--build-item-spec locator))

(defun increamemo-file-backend-find-live-duplicate-id (connection item-spec)
  "Return a live duplicate id for ITEM-SPEC on CONNECTION, or nil."
  (increamemo-storage-select-value
   connection
   (concat
    "SELECT i.id "
    "FROM increamemo_items i "
    "JOIN increamemo_file_items f ON f.item_id = i.id "
    "WHERE i.type = 'file' AND f.path = ? "
    "AND i.state IN ('active', 'invalid') "
    "LIMIT 1")
   (list (plist-get item-spec :path))))

(defun increamemo-file-backend-insert-item-data (connection item-id item-spec)
  "Insert subtype data for ITEM-ID and ITEM-SPEC on CONNECTION."
  (increamemo-storage-execute
   connection
   "INSERT INTO increamemo_file_items(item_id, path) VALUES(?, ?)"
   (list item-id (plist-get item-spec :path))))

(defun increamemo-file-backend-hydrate-item (connection item)
  "Return ITEM enriched with file subtype data from CONNECTION."
  (let ((path
         (increamemo-storage-select-value
          connection
          "SELECT path FROM increamemo_file_items WHERE item_id = ?"
          (list (plist-get item :id)))))
    (unless path
      (user-error "Increamemo: file item %s is missing subtype data"
                  (plist-get item :id)))
    (plist-put (copy-sequence item) :path path)))

(defun increamemo-file-backend-open-item (item)
  "Open file ITEM and return the resulting buffer."
  (let* ((path (or (plist-get item :path)
                   (user-error "Increamemo: file item has no path")))
         (normalized-path (increamemo-file-backend--validate-path path))
         (opener (increamemo-file-backend--resolve-opener normalized-path))
         (result (funcall opener normalized-path))
         (buffer (cond
                  ((bufferp result) result)
                  ((windowp result) (window-buffer result))
                  (t (current-buffer)))))
    (unless (buffer-live-p buffer)
      (user-error "Increamemo: file backend did not return a live buffer"))
    buffer))

(provide 'increamemo-backend-file)
;;; increamemo-backend-file.el ends here
