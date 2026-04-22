;;; increamemo-backend-ekg-test.el --- EKG backend tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for the EKG backend.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo-backend-ekg)

(ert-deftest increamemo-ekg-backend-recognizes-current-note-buffer ()
  "The EKG backend returns a source ref for an EKG note buffer."
  (with-temp-buffer
    (rename-buffer "*ekg topic*" t)
    (setq-local ekg-note '(:id 42))
    (cl-letf (((symbol-function 'ekg-note-id)
               (lambda (note)
                 (plist-get note :id))))
      (let ((source-ref
             (increamemo-ekg-backend-recognize-current (current-buffer))))
        (should (equal (plist-get source-ref :type) "ekg"))
        (should (equal (plist-get source-ref :locator) "42"))
        (should (eq (plist-get source-ref :opener)
                    'increamemo-ekg-open-note))
        (should (equal (plist-get source-ref :title-snapshot)
                       "*ekg topic*"))))))

(ert-deftest increamemo-ekg-backend-returns-nil-for-non-ekg-buffer ()
  "The EKG backend ignores unrelated buffers."
  (with-temp-buffer
    (should-not
     (increamemo-ekg-backend-recognize-current (current-buffer)))))

(ert-deftest increamemo-ekg-backend-errors-when-ekg-functions-are-missing ()
  "The EKG backend raises an error for EKG buffers without required APIs."
  (with-temp-buffer
    (setq-local ekg-note '(:id 42))
    (should-error
     (increamemo-ekg-backend-recognize-current (current-buffer))
     :type 'user-error)))

(ert-deftest increamemo-ekg-backend-requires-note-id ()
  "The EKG backend requires the current note to provide an identifier."
  (with-temp-buffer
    (setq-local ekg-note '(:id nil))
    (cl-letf (((symbol-function 'ekg-note-id)
               (lambda (_note) nil)))
      (should-error
       (increamemo-ekg-backend-recognize-current (current-buffer))
       :type 'user-error))))

(ert-deftest increamemo-ekg-open-note-opens-note-by-id ()
  "The EKG opener wrapper loads and opens the note matching the locator."
  (let ((opened-note nil)
        (opened-buffer (generate-new-buffer "*ekg opened*")))
    (unwind-protect
        (cl-letf (((symbol-function 'ekg-get-note-with-id)
                   (lambda (note-id)
                     (should (= note-id 42))
                     '(:id 42 :text "note")))
                  ((symbol-function 'ekg-edit)
                   (lambda (note)
                     (setq opened-note note)
                     opened-buffer)))
          (should (eq (increamemo-ekg-open-note "42")
                      opened-buffer))
          (should (equal opened-note '(:id 42 :text "note"))))
      (kill-buffer opened-buffer))))

(ert-deftest increamemo-ekg-open-note-errors-when-note-is-missing ()
  "The EKG opener wrapper raises an error when no note matches the locator."
  (cl-letf (((symbol-function 'ekg-get-note-with-id)
             (lambda (_note-id) nil)))
    (should-error
     (increamemo-ekg-open-note "42")
     :type 'user-error)))

(ert-deftest increamemo-ekg-backend-builds-manual-source-ref ()
  "The EKG backend provides default opener and title for manual items."
  (cl-letf (((symbol-function 'ekg-get-note-with-id)
             (lambda (_note-id) nil))
            ((symbol-function 'ekg-edit)
             (lambda (_note) nil)))
    (let ((source-ref (increamemo-ekg-backend-build-source-ref "ekg" "42")))
      (should (equal (plist-get source-ref :type) "ekg"))
      (should (equal (plist-get source-ref :locator) "42"))
      (should (eq (plist-get source-ref :opener) 'increamemo-ekg-open-note))
      (should (equal (plist-get source-ref :title-snapshot) "42")))))

(ert-deftest increamemo-ekg-backend-build-source-ref-validates-locator ()
  "Manual EKG source refs reject invalid locator syntax."
  (should-error
   (increamemo-ekg-backend-build-source-ref "ekg" "(")
   :type 'user-error))

(ert-deftest increamemo-ekg-backend-build-source-ref-requires-ekg-opening-api ()
  "Manual EKG source refs require the EKG opening functions."
  (should-error
   (increamemo-ekg-backend-build-source-ref "ekg" "42")
   :type 'user-error))

(provide 'increamemo-backend-ekg-test)
;;; increamemo-backend-ekg-test.el ends here
