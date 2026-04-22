;;; increamemo-backend.el --- Backend registry for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Backend registry and source-ref dispatch.

;;; Code:

(require 'increamemo-backend-ekg)
(require 'increamemo-backend-file)
(require 'increamemo-config)

(defun increamemo-backend--function (backend suffix)
  "Return BACKEND function named by SUFFIX.

BACKEND follows the registry contract exposed by `increamemo-backends'."
  (unless (symbolp backend)
    (user-error "Increamemo: invalid backend: %S" backend))
  (let ((function-symbol
         (intern-soft (format "%s-%s" backend suffix))))
    (unless (fboundp function-symbol)
      (user-error "Increamemo: unknown backend: %S" backend))
    function-symbol))

(defun increamemo-backend--recognizer (backend)
  "Return the recognizer function for BACKEND."
  (increamemo-backend--function backend "recognize-current"))

(defun increamemo-backend--builder (backend)
  "Return the manual source-ref builder for BACKEND."
  (increamemo-backend--function backend "build-source-ref"))

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

(defun increamemo-backend-build-source-ref (type locator &optional opener)
  "Return a source ref for TYPE, LOCATOR, and optional OPENER."
  (let ((source-ref nil))
    (dolist (backend increamemo-backends)
      (unless source-ref
        (setq source-ref
              (funcall (increamemo-backend--builder backend)
                       type
                       locator
                       opener))))
    (or source-ref
        (user-error "Increamemo: no backend recognized type: %s" type))))

(provide 'increamemo-backend)
;;; increamemo-backend.el ends here
