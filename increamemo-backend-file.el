;;; increamemo-backend-file.el --- File backend for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; File-backed source recognition.

;;; Code:

(require 'increamemo-config)

(defconst increamemo-file-backend 'increamemo-file-backend
  "Symbol used for the file backend.")

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

(defun increamemo-file-backend--resolve-opener (extension)
  "Return the configured opener for EXTENSION."
  (cdr (assoc-string extension increamemo-file-openers t)))

(defun increamemo-file-backend--build-source-ref (buffer)
  "Return a file source ref for BUFFER, or nil when BUFFER is unrelated."
  (with-current-buffer buffer
    (when-let ((file-name buffer-file-name))
      (let* ((locator (increamemo-file-backend--normalize-path file-name))
             (extension (increamemo-file-backend--file-extension locator)))
        (unless (file-exists-p locator)
          (user-error "Increamemo: file does not exist: %s" locator))
        (unless (increamemo-file-backend--supported-format-p extension)
          (user-error "Increamemo: unsupported file format: %s" extension))
        (let ((opener (increamemo-file-backend--resolve-opener extension)))
          (unless (functionp opener)
            (user-error
             "Increamemo: no opener configured for extension: %s"
             extension))
          (list :type "file"
                :locator locator
                :opener opener
                :title-snapshot (file-name-nondirectory locator)))))))

(defun increamemo-file-backend-build-source-ref (type locator &optional opener)
  "Return a file source ref for TYPE, LOCATOR, and optional OPENER."
  (when (string= type "file")
    (let* ((normalized-locator (increamemo-file-backend--normalize-path locator))
           (extension (increamemo-file-backend--file-extension normalized-locator)))
      (unless (file-exists-p normalized-locator)
        (user-error "Increamemo: file does not exist: %s" normalized-locator))
      (unless (increamemo-file-backend--supported-format-p extension)
        (user-error "Increamemo: unsupported file format: %s" extension))
      (let ((resolved-opener (or opener
                                 (increamemo-file-backend--resolve-opener
                                  extension))))
        (unless resolved-opener
          (user-error
           "Increamemo: no opener configured for extension: %s"
           extension))
        (list :type "file"
              :locator normalized-locator
              :opener resolved-opener
              :title-snapshot
              (file-name-nondirectory normalized-locator))))))

(defun increamemo-file-backend-recognize-current (&optional buffer)
  "Return a source ref for BUFFER when it is a supported file buffer."
  (increamemo-file-backend--build-source-ref (or buffer (current-buffer))))

(defun increamemo-file-backend-source-ref (&optional buffer)
  "Return a source ref for BUFFER or raise `user-error'."
  (or (increamemo-file-backend-recognize-current buffer)
      (user-error "Increamemo: current buffer is not a supported file item")))

(provide 'increamemo-backend-file)
;;; increamemo-backend-file.el ends here
