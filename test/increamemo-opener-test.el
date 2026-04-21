;;; increamemo-opener-test.el --- Opener tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for item opening side effects.

;;; Code:

(require 'ert)
(require 'increamemo-opener)
(require 'increamemo-test-support)

(defun increamemo-opener-test--item (locator opener)
  "Return a file item plist for LOCATOR and OPENER."
  (list :id 42
        :type "file"
        :locator locator
        :opener opener))

(ert-deftest increamemo-opener-opens-file-item-with-resolved-opener ()
  "Opening a file item returns the opened buffer."
  (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
    (let ((opened-buffer
           (increamemo-opener-open-item
            (increamemo-opener-test--item
             (expand-file-name buffer-file-name)
             "find-file"))))
      (unwind-protect
          (should (equal (buffer-file-name opened-buffer)
                         (expand-file-name buffer-file-name)))
        (when (buffer-live-p opened-buffer)
          (kill-buffer opened-buffer))))))

(ert-deftest increamemo-opener-rejects-unresolved-opener ()
  "Opening fails when the opener symbol cannot be resolved."
  (should-error
   (increamemo-opener-open-item
    (increamemo-opener-test--item "/tmp/topic.md" "missing-opener"))
   :type 'increamemo-opener-error))

(ert-deftest increamemo-opener-rejects-missing-file-before-opening ()
  "Opening fails when the file locator does not exist."
  (should-error
   (increamemo-opener-open-item
    (increamemo-opener-test--item "/tmp/increamemo-missing-file.md" "find-file"))
   :type 'increamemo-opener-error))

(ert-deftest increamemo-opener-wraps-opener-execution-errors ()
  "Opening fails with a classified opener error when the opener raises."
  (cl-letf (((symbol-function 'increamemo-opener-test-broken-opener)
             (lambda (&rest _args)
               (error "broken opener"))))
    (increamemo-test-support-with-file-buffer "notes/topic.md" "# title"
      (should-error
       (increamemo-opener-open-item
        (increamemo-opener-test--item
         (expand-file-name buffer-file-name)
         "increamemo-opener-test-broken-opener"))
       :type 'increamemo-opener-error))))

(provide 'increamemo-opener-test)
;;; increamemo-opener-test.el ends here
