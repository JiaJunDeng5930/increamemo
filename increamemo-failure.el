;;; increamemo-failure.el --- Failure policy for increamemo  -*- lexical-binding: t; -*-

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

;; Open failure policy adapter.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-domain)

(defun increamemo-failure--message (open-error)
  "Return the user-visible message from OPEN-ERROR."
  (plist-get (car (cdr open-error)) :message))

(defun increamemo-failure--missing-item-error-p (err)
  "Return non-nil when ERR reports a missing scheduled item."
  (and (eq (car err) 'user-error)
       (string-match-p
        "\\`Increamemo: item [0-9]+ does not exist\\'"
        (error-message-string err))))

(defun increamemo-failure--handle-delete-policy (item-id message-text occurred-at)
  "Apply the delete failure policy for ITEM-ID with MESSAGE-TEXT at OCCURRED-AT."
  (condition-case err
      (progn
        (increamemo-domain-record-open-failure item-id message-text occurred-at)
        (increamemo-domain-delete-item item-id occurred-at))
    (user-error
     (if (increamemo-failure--missing-item-error-p err)
         (increamemo-domain-delete-item item-id occurred-at)
       (signal (car err) (cdr err))))))

(defun increamemo-failure-handle-open-error (item open-error &optional occurred-at)
  "Apply the configured failure policy for ITEM and OPEN-ERROR.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((item-id (plist-get item :id))
        (message-text (increamemo-failure--message open-error)))
    (pcase increamemo-invalid-opener-policy
      ('keep
       (increamemo-domain-mark-invalid item-id message-text occurred-at))
      ('archive
       (increamemo-domain-record-open-failure item-id message-text occurred-at)
       (increamemo-domain-archive-item item-id occurred-at))
      ('delete
       (increamemo-failure--handle-delete-policy
        item-id
        message-text
        occurred-at))
      (_
       (user-error "Increamemo: invalid opener policy: %S"
                   increamemo-invalid-opener-policy)))))

(provide 'increamemo-failure)
;;; increamemo-failure.el ends here
