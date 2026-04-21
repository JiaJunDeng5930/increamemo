;;; increamemo-opener.el --- Opening side effects for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Opening side effects and opener failure classification.

;;; Code:

(define-error 'increamemo-opener-error "Increamemo opener error")

(defun increamemo-opener--signal (reason item format-string &rest args)
  "Signal an opener error for ITEM with REASON using FORMAT-STRING and ARGS."
  (let ((message-text (apply #'format format-string args)))
    (signal 'increamemo-opener-error
            (list (list :reason reason
                        :item item
                        :message message-text)))))

(defun increamemo-opener--resolve-opener (opener)
  "Return the callable function named by OPENER."
  (let ((symbol
         (cond
          ((symbolp opener) opener)
          ((stringp opener) (intern-soft opener))
          (t nil))))
    (and symbol
         (fboundp symbol)
         symbol)))

(defun increamemo-opener--require-file-exists (item)
  "Ensure the file ITEM points to an existing file."
  (let ((locator (plist-get item :locator)))
    (unless (and (stringp locator)
                 (> (length locator) 0))
      (increamemo-opener--signal
       'missing-locator item "Increamemo: item has no locator"))
    (unless (file-exists-p locator)
      (increamemo-opener--signal
       'missing-file item "Increamemo: file does not exist: %s" locator))
    locator))

(defun increamemo-opener--prepare-arguments (item)
  "Return the argument list for opening ITEM."
  (pcase (plist-get item :type)
    ("file" (list (increamemo-opener--require-file-exists item)))
    (_
     (let ((locator (plist-get item :locator)))
       (unless (and (stringp locator)
                    (> (length locator) 0))
         (increamemo-opener--signal
          'missing-locator item "Increamemo: item has no locator"))
       (list locator)))))

(defun increamemo-opener-open-item (item)
  "Open ITEM and return the resulting buffer."
  (let* ((opener-name (plist-get item :opener))
         (opener (increamemo-opener--resolve-opener opener-name)))
    (unless opener
      (increamemo-opener--signal
       'unresolved-opener item "Increamemo: unresolved opener: %s" opener-name))
    (condition-case err
        (let* ((result (apply opener (increamemo-opener--prepare-arguments item)))
               (buffer
                (cond
                 ((bufferp result) result)
                 ((windowp result) (window-buffer result))
                 (t (current-buffer)))))
          (unless (buffer-live-p buffer)
            (increamemo-opener--signal
             'invalid-buffer item "Increamemo: opener did not return a live buffer"))
          buffer)
      (increamemo-opener-error
       (signal (car err) (cdr err)))
      (error
       (increamemo-opener--signal
        'opener-error item "Increamemo: opener failed: %s"
        (error-message-string err))))))

(provide 'increamemo-opener)
;;; increamemo-opener.el ends here
