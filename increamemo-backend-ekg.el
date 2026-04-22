;;; increamemo-backend-ekg.el --- EKG backend for increamemo  -*- lexical-binding: t; -*-

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

;; EKG-backed source recognition and storage.

;;; Code:

(require 'increamemo-storage)

(defconst increamemo-ekg-backend 'increamemo-ekg-backend
  "Symbol used for the EKG backend.")

(declare-function ekg-edit "ext:ekg" (note))
(declare-function ekg-get-note-with-id "ext:ekg" (id))
(declare-function ekg-note-id "ext:ekg" (note))
(defvar ekg-note)

(defun increamemo-ekg-backend-type ()
  "Return the item type string for the EKG backend."
  "ekg")

(defun increamemo-ekg-backend--ekg-buffer-p (buffer)
  "Return non-nil when BUFFER represents an EKG note buffer."
  (with-current-buffer buffer
    (local-variable-p 'ekg-note buffer)))

(defun increamemo-ekg-backend--require-function (symbol)
  "Ensure SYMBOL is callable and return it."
  (unless (fboundp symbol)
    (user-error "Increamemo: missing ekg function: %S" symbol))
  symbol)

(defun increamemo-ekg-backend--normalize-note-id (note-id)
  "Return NOTE-ID serialized as a readable string."
  (condition-case nil
      (prin1-to-string (read note-id))
    (error
     (user-error "Increamemo: invalid ekg note id: %S" note-id))))

(defun increamemo-ekg-backend--build-item-spec (note-id &optional title-snapshot)
  "Return an EKG item spec for NOTE-ID and TITLE-SNAPSHOT."
  (let ((normalized-note-id
         (increamemo-ekg-backend--normalize-note-id note-id)))
    (increamemo-ekg-backend--require-function 'ekg-get-note-with-id)
    (increamemo-ekg-backend--require-function 'ekg-edit)
    (list :type "ekg"
          :title-snapshot (or title-snapshot normalized-note-id)
          :note-id normalized-note-id)))

(defun increamemo-ekg-backend-recognize-current (&optional buffer)
  "Return an EKG item spec for BUFFER, or nil when unrelated."
  (let ((target-buffer (or buffer (current-buffer))))
    (when (increamemo-ekg-backend--ekg-buffer-p target-buffer)
      (increamemo-ekg-backend--require-function 'ekg-note-id)
      (with-current-buffer target-buffer
        (let ((note-id (ekg-note-id ekg-note)))
          (when (null note-id)
            (user-error "Increamemo: missing ekg note id"))
          (increamemo-ekg-backend--build-item-spec
           (prin1-to-string note-id)
           (buffer-name target-buffer)))))))

(defun increamemo-ekg-backend-prompt-new-item ()
  "Prompt for an EKG item and return its item spec."
  (increamemo-ekg-backend--build-item-spec
   (read-string "EKG note id: ")))

(defun increamemo-ekg-backend-build-source-ref (_type locator &optional _opener)
  "Return an EKG item spec for LOCATOR."
  (increamemo-ekg-backend--build-item-spec locator))

(defun increamemo-ekg-backend-find-live-duplicate-id (connection item-spec)
  "Return a live duplicate id for ITEM-SPEC on CONNECTION, or nil."
  (increamemo-storage-select-value
   connection
   (concat
    "SELECT i.id "
    "FROM increamemo_items i "
    "JOIN increamemo_ekg_items e ON e.item_id = i.id "
    "WHERE i.type = 'ekg' AND e.note_id = ? "
    "AND i.state IN ('active', 'invalid') "
    "LIMIT 1")
   (list (plist-get item-spec :note-id))))

(defun increamemo-ekg-backend-insert-item-data (connection item-id item-spec)
  "Insert subtype data for ITEM-ID and ITEM-SPEC on CONNECTION."
  (increamemo-storage-execute
   connection
   "INSERT INTO increamemo_ekg_items(item_id, note_id) VALUES(?, ?)"
   (list item-id (plist-get item-spec :note-id))))

(defun increamemo-ekg-backend-hydrate-item (connection item)
  "Return ITEM enriched with EKG subtype data from CONNECTION."
  (let ((note-id
         (increamemo-storage-select-value
          connection
          "SELECT note_id FROM increamemo_ekg_items WHERE item_id = ?"
          (list (plist-get item :id)))))
    (unless note-id
      (user-error "Increamemo: ekg item %s is missing subtype data"
                  (plist-get item :id)))
    (plist-put (copy-sequence item) :note-id note-id)))

(defun increamemo-ekg-open-note (note-id)
  "Open the EKG note identified by NOTE-ID."
  (increamemo-ekg-backend--require-function 'ekg-get-note-with-id)
  (increamemo-ekg-backend--require-function 'ekg-edit)
  (let* ((parsed-note-id (read note-id))
         (note (ekg-get-note-with-id parsed-note-id)))
    (unless note
      (user-error "Increamemo: ekg note not found: %s" note-id))
    (ekg-edit note)))

(defun increamemo-ekg-backend-open-item (item)
  "Open EKG ITEM and return the resulting buffer."
  (let ((note-id (or (plist-get item :note-id)
                     (user-error "Increamemo: ekg item has no note id"))))
    (let* ((result (increamemo-ekg-open-note note-id))
           (buffer (cond
                    ((bufferp result) result)
                    ((windowp result) (window-buffer result))
                    (t (current-buffer)))))
      (unless (buffer-live-p buffer)
        (user-error "Increamemo: ekg backend did not return a live buffer"))
      buffer)))

(provide 'increamemo-backend-ekg)
;;; increamemo-backend-ekg.el ends here
