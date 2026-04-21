;;; increamemo-backend.el --- Backend registry for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Backend registry and source-ref dispatch.

;;; Code:

(require 'increamemo-backend-ekg)
(require 'increamemo-backend-file)
(require 'increamemo-config)

(defun increamemo-backend--recognizer (backend)
  "Return the recognizer function for BACKEND."
  (pcase backend
    ('increamemo-file-backend #'increamemo-file-backend-recognize-current)
    ('increamemo-ekg-backend #'increamemo-ekg-backend-recognize-current)
    (_ (user-error "Increamemo: unknown backend: %S" backend))))

(defun increamemo-backend-identify-current (&optional buffer)
  "Return a source ref for BUFFER using the configured backends."
  (let ((target-buffer (or buffer (current-buffer)))
        (source-ref nil))
    (dolist (backend increamemo-backends)
      (unless source-ref
        (setq source-ref
              (funcall (increamemo-backend--recognizer backend)
                       target-buffer))))
    (or source-ref
        (user-error "Increamemo: no backend recognized the current buffer"))))

(provide 'increamemo-backend)
;;; increamemo-backend.el ends here
