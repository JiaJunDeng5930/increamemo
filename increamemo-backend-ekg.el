;;; increamemo-backend-ekg.el --- EKG backend for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; EKG-backed source recognition and opener wrapping.

;;; Code:

(defconst increamemo-ekg-backend 'increamemo-ekg-backend
  "Symbol used for the EKG backend.")

(declare-function ekg-edit "ext:ekg" (note))
(declare-function ekg-get-note-with-id "ext:ekg" (id))
(declare-function ekg-note-id "ext:ekg" (note))
(defvar ekg-note)

(defun increamemo-ekg-backend--ekg-buffer-p (buffer)
  "Return non-nil when BUFFER represents an EKG note buffer."
  (with-current-buffer buffer
    (local-variable-p 'ekg-note buffer)))

(defun increamemo-ekg-backend--require-function (symbol)
  "Ensure SYMBOL is callable and return it."
  (unless (fboundp symbol)
    (user-error "Increamemo: missing ekg function: %S" symbol))
  symbol)

(defun increamemo-ekg-backend--require-note-id (note-id)
  "Ensure NOTE-ID is present and return it."
  (when (null note-id)
    (user-error "Increamemo: missing ekg note id"))
  note-id)

(defun increamemo-ekg-backend--normalize-locator (locator)
  "Return a normalized EKG LOCATOR."
  (condition-case nil
      (prin1-to-string (read locator))
    (error
     (user-error "Increamemo: invalid ekg locator: %S" locator))))

(defun increamemo-ekg-backend-recognize-current (&optional buffer)
  "Return a source ref for BUFFER when it is an EKG note buffer."
  (let ((target-buffer (or buffer (current-buffer))))
    (when (increamemo-ekg-backend--ekg-buffer-p target-buffer)
      (increamemo-ekg-backend--require-function 'ekg-note-id)
      (with-current-buffer target-buffer
        (let ((note-id
               (increamemo-ekg-backend--require-note-id
                (ekg-note-id ekg-note))))
          (list :type "ekg"
                :locator (prin1-to-string note-id)
                :opener 'increamemo-ekg-open-note
                :title-snapshot (buffer-name target-buffer)))))))

(defun increamemo-ekg-backend-build-source-ref (type locator &optional opener)
  "Return an EKG source ref for TYPE, LOCATOR, and optional OPENER."
  (when (string= type "ekg")
    (let ((normalized-locator
           (increamemo-ekg-backend--normalize-locator locator)))
      (increamemo-ekg-backend--require-function 'ekg-get-note-with-id)
      (increamemo-ekg-backend--require-function 'ekg-edit)
    (list :type "ekg"
          :locator normalized-locator
          :opener (or opener 'increamemo-ekg-open-note)
          :title-snapshot normalized-locator))))

(defun increamemo-ekg-open-note (locator)
  "Open the EKG note identified by LOCATOR."
  (increamemo-ekg-backend--require-function 'ekg-get-note-with-id)
  (increamemo-ekg-backend--require-function 'ekg-edit)
  (let* ((note-id (read locator))
         (note (ekg-get-note-with-id note-id)))
    (unless note
      (user-error "Increamemo: ekg note not found: %s" locator))
    (ekg-edit note)))

(provide 'increamemo-backend-ekg)
;;; increamemo-backend-ekg.el ends here
