;;; increamemo-backend-file-test.el --- File backend tests  -*- lexical-binding: t; -*-

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

(ert-deftest increamemo-backend-registry-supports-custom-backends ()
  "Configured backends follow the registry naming contract."
  (let ((increamemo-backends '(increamemo-test-backend)))
    (cl-letf (((symbol-function 'increamemo-test-backend-recognize-current)
               (lambda (_buffer)
                 '(:type "test"
                   :locator "current"
                   :opener test-open
                   :title-snapshot "Current")))
              ((symbol-function 'increamemo-test-backend-build-source-ref)
               (lambda (type locator &optional opener)
                 (when (string= type "test")
                   (list :type type
                         :locator locator
                         :opener (or opener 'test-open)
                         :title-snapshot "Manual")))))
      (with-temp-buffer
        (let ((identified
               (increamemo-backend-identify-current (current-buffer)))
              (manual
               (increamemo-backend-build-source-ref
                "test"
                "manual"
                'manual-open)))
          (should (equal (plist-get identified :type) "test"))
          (should (equal (plist-get identified :locator) "current"))
          (should (eq (plist-get manual :opener) 'manual-open))
          (should (equal (plist-get manual :locator) "manual")))))))

(ert-deftest increamemo-backend-registry-loads-configured-backend-feature ()
  "Configured backends load their feature before resolving dispatch functions."
  (let* ((temp-dir (make-temp-file "increamemo-backend-feature-" t))
         (feature-file (expand-file-name "increamemo-backend-temp.el" temp-dir))
         (load-path (cons temp-dir load-path))
         (increamemo-backends '(increamemo-temp-backend)))
    (unwind-protect
        (progn
          (with-temp-file feature-file
            (insert ";;; increamemo-backend-temp.el --- temp backend -*- lexical-binding: t; -*-\n")
            (insert "(defun increamemo-temp-backend-recognize-current (_buffer)\n")
            (insert "  (list :type \"temp\" :locator \"loaded\" :opener 'temp-open :title-snapshot \"Loaded\"))\n")
            (insert "(defun increamemo-temp-backend-build-source-ref (type locator &optional opener)\n")
            (insert "  (when (string= type \"temp\")\n")
            (insert "    (list :type type :locator locator :opener (or opener 'temp-open) :title-snapshot \"Manual\")))\n")
            (insert "(provide 'increamemo-backend-temp)\n"))
          (let ((recognized (increamemo-backend-identify-current (current-buffer)))
                (manual (increamemo-backend-build-source-ref "temp" "manual")))
            (should (equal (plist-get recognized :locator) "loaded"))
            (should (eq (plist-get manual :opener) 'temp-open))))
      (ignore-errors
        (unload-feature 'increamemo-backend-temp t))
      (delete-directory temp-dir t))))

(ert-deftest increamemo-backend-registry-loads-increamemo-named-backend-feature ()
  "Increamemo-prefixed backends can load from their matching feature name."
  (let* ((temp-dir (make-temp-file "increamemo-backend-feature-" t))
         (feature-file (expand-file-name "increamemo-temp-backend.el" temp-dir))
         (load-path (cons temp-dir load-path))
         (increamemo-backends '(increamemo-temp-backend)))
    (unwind-protect
        (progn
          (with-temp-file feature-file
            (insert ";;; increamemo-temp-backend.el --- temp backend -*- lexical-binding: t; -*-\n")
            (insert "(defun increamemo-temp-backend-recognize-current (_buffer)\n")
            (insert "  (list :type \"temp\" :locator \"prefixed\" :opener 'temp-open :title-snapshot \"Prefixed\"))\n")
            (insert "(defun increamemo-temp-backend-build-source-ref (type locator &optional opener)\n")
            (insert "  (when (string= type \"temp\")\n")
            (insert "    (list :type type :locator locator :opener (or opener 'temp-open) :title-snapshot \"Manual\")))\n")
            (insert "(provide 'increamemo-temp-backend)\n"))
          (let ((recognized (increamemo-backend-identify-current (current-buffer)))
                (manual (increamemo-backend-build-source-ref "temp" "manual")))
            (should (equal (plist-get recognized :locator) "prefixed"))
            (should (eq (plist-get manual :opener) 'temp-open))))
      (ignore-errors
        (unload-feature 'increamemo-temp-backend t))
      (delete-directory temp-dir t))))

(ert-deftest increamemo-backend-registry-loads-external-backend-feature ()
  "External backends load from their own feature name."
  (let* ((temp-dir (make-temp-file "external-backend-feature-" t))
         (feature-file (expand-file-name "temp-backend.el" temp-dir))
         (load-path (cons temp-dir load-path))
         (increamemo-backends '(temp-backend)))
    (unwind-protect
        (progn
          (with-temp-file feature-file
            (insert ";;; temp-backend.el --- temp backend -*- lexical-binding: t; -*-\n")
            (insert "(defun temp-backend-recognize-current (_buffer)\n")
            (insert "  (list :type \"temp\" :locator \"external\" :opener 'temp-open :title-snapshot \"External\"))\n")
            (insert "(defun temp-backend-build-source-ref (type locator &optional opener)\n")
            (insert "  (when (string= type \"temp\")\n")
            (insert "    (list :type type :locator locator :opener (or opener 'temp-open) :title-snapshot \"Manual\")))\n")
            (insert "(provide 'temp-backend)\n"))
          (let ((recognized (increamemo-backend-identify-current (current-buffer)))
                (manual (increamemo-backend-build-source-ref "temp" "manual")))
            (should (equal (plist-get recognized :locator) "external"))
            (should (eq (plist-get manual :opener) 'temp-open))))
      (ignore-errors
        (unload-feature 'temp-backend t))
      (delete-directory temp-dir t))))

(ert-deftest increamemo-backend-build-source-ref-normalizes-manual-file-entry ()
  "The backend registry builds file source refs for manual entry."
  (let ((increamemo-supported-file-formats '("md"))
        (increamemo-file-openers '(("md" . find-file))))
    (let* ((temp-dir (make-temp-file "increamemo-backend-file-manual-" t))
           (default-directory temp-dir)
           (relative-path "notes/manual.md")
           (absolute-path (expand-file-name relative-path temp-dir)))
      (unwind-protect
          (progn
            (make-directory (file-name-directory absolute-path) t)
            (with-temp-file absolute-path
              (insert "# manual"))
            (let ((source-ref
                   (increamemo-backend-build-source-ref "file" relative-path)))
              (should (equal (plist-get source-ref :type) "file"))
              (should (equal (plist-get source-ref :locator) absolute-path))
              (should (eq (plist-get source-ref :opener) 'find-file))
              (should (equal (plist-get source-ref :title-snapshot)
                             "manual.md"))))
        (delete-directory temp-dir t)))))

(provide 'increamemo-backend-file-test)
;;; increamemo-backend-file-test.el ends here
