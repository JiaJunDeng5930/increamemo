;;; increamemo-backend-file-test.el --- File backend tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for file backend recognition.

;;; Code:

(require 'ert)
(require 'increamemo-backend)
(require 'increamemo-config)

(defmacro increamemo-backend-file-test-with-file-buffer
    (filename contents &rest body)
  "Run BODY with a visiting buffer for FILENAME containing CONTENTS."
  (declare (indent 2) (debug (form form body)))
  `(let* ((temp-dir (make-temp-file "increamemo-backend-file-" t))
          (file-path (expand-file-name ,filename temp-dir)))
     (unwind-protect
         (progn
           (make-directory (file-name-directory file-path) t)
           (with-temp-file file-path
             (insert ,contents))
           (let ((buffer (find-file-noselect file-path)))
             (unwind-protect
                 (with-current-buffer buffer
                   ,@body)
               (when (buffer-live-p buffer)
                 (kill-buffer buffer)))))
       (delete-directory temp-dir t))))

(ert-deftest increamemo-file-backend-builds-source-ref-for-supported-file ()
  "The file backend normalizes supported file buffers into source refs."
  (let ((increamemo-supported-file-formats '("md" "org"))
        (increamemo-file-openers '(("md" . find-file)
                                   ("org" . find-file-other-window))))
    (increamemo-backend-file-test-with-file-buffer "notes/topic.md" "# title"
      (let ((source-ref (increamemo-file-backend-source-ref (current-buffer))))
        (should (equal (plist-get source-ref :type) "file"))
        (should (equal (plist-get source-ref :locator)
                       (expand-file-name buffer-file-name)))
        (should (eq (plist-get source-ref :opener) 'find-file))
        (should (equal (plist-get source-ref :title-snapshot)
                       "topic.md"))))))

(ert-deftest increamemo-file-backend-rejects-unsupported-extensions ()
  "The file backend rejects buffers whose extension is not supported."
  (let ((increamemo-supported-file-formats '("org")))
    (increamemo-backend-file-test-with-file-buffer "notes/topic.md" "# title"
      (should-error
       (increamemo-file-backend-source-ref (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-file-backend-rejects-missing-files ()
  "The file backend requires the visited file to exist."
  (let ((increamemo-supported-file-formats '("md")))
    (with-temp-buffer
      (set-visited-file-name "/tmp/increamemo-missing-note.md" t)
      (should-error
       (increamemo-file-backend-source-ref (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-backend-identify-current-uses-configured-backends ()
  "The backend registry selects the first configured backend that resolves."
  (let ((increamemo-supported-file-formats '("md"))
        (increamemo-file-openers '(("md" . find-file)))
        (increamemo-backends '(increamemo-file-backend)))
    (increamemo-backend-file-test-with-file-buffer "notes/topic.md" "# title"
      (let ((source-ref
             (increamemo-backend-identify-current (current-buffer))))
        (should (equal (plist-get source-ref :type) "file"))
        (should (equal (plist-get source-ref :locator)
                       (expand-file-name buffer-file-name)))))))

(ert-deftest increamemo-backend-identify-current-rejects-unknown-backend ()
  "The backend registry raises an error for unknown backend symbols."
  (let ((increamemo-backends '(missing-backend)))
    (with-temp-buffer
      (should-error
       (increamemo-backend-identify-current (current-buffer))
       :type 'user-error))))

(provide 'increamemo-backend-file-test)
;;; increamemo-backend-file-test.el ends here
