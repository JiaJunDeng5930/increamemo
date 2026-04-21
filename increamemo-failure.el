;;; increamemo-failure.el --- Failure policy for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Open failure policy adapter.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-domain)

(defun increamemo-failure--message (open-error)
  "Return the user-visible message from OPEN-ERROR."
  (plist-get (car (cdr open-error)) :message))

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
       (increamemo-domain-record-open-failure item-id message-text occurred-at)
       (increamemo-domain-delete-item item-id occurred-at))
      (_
       (user-error "Increamemo: invalid opener policy: %S"
                   increamemo-invalid-opener-policy)))))

(provide 'increamemo-failure)
;;; increamemo-failure.el ends here
