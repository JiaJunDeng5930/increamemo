;;; increamemo-board-test.el --- Board tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for the board runtime.

;;; Code:

(require 'ert)
(require 'increamemo)
(require 'increamemo-board)
(require 'increamemo-domain)
(require 'increamemo-test-support)

(defun increamemo-board-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :locator path
        :opener 'find-file
        :title-snapshot (file-name-nondirectory path)))

(defun increamemo-board-test--write-note (root name)
  "Create note NAME under ROOT and return its absolute path."
  (let ((path (expand-file-name name root)))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert name))
    path))

(defun increamemo-board-test--entry-labels (entries)
  "Return the title column from ENTRIES."
  (mapcar (lambda (entry) (aref (cadr entry) 5)) entries))

(defun increamemo-board-test--setup-items (root)
  "Create planned, due, invalid, and archived items under ROOT."
  (let* ((planned-path (increamemo-board-test--write-note root "notes/planned.md"))
         (due-path (increamemo-board-test--write-note root "notes/due.md"))
         (invalid-path (increamemo-board-test--write-note root "notes/invalid.md"))
         (archived-path (increamemo-board-test--write-note root "notes/archived.md"))
         (invalid-item nil)
         (archived-item nil))
    (increamemo-domain-ensure-item
     (increamemo-board-test--source-ref planned-path)
     30
     "2026-04-25"
     "2026-04-21T08:00:00+00:00")
    (increamemo-domain-ensure-item
     (increamemo-board-test--source-ref due-path)
     10
     "2026-04-21"
     "2026-04-21T08:01:00+00:00")
    (setq invalid-item
          (increamemo-domain-ensure-item
           (increamemo-board-test--source-ref invalid-path)
           20
           "2026-04-21"
           "2026-04-21T08:02:00+00:00"))
    (increamemo-domain-mark-invalid
     (plist-get invalid-item :id)
     "broken"
     "2026-04-21T09:00:00+00:00")
    (setq archived-item
          (increamemo-domain-ensure-item
           (increamemo-board-test--source-ref archived-path)
           40
           "2026-04-21"
           "2026-04-21T08:03:00+00:00"))
    (increamemo-domain-archive-item
     (plist-get archived-item :id)
     "2026-04-21T09:01:00+00:00")))

(ert-deftest increamemo-board-open-renders-planned-items-by-default ()
  "Board opens with planned active items by default."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (should (eq major-mode 'increamemo-board-mode))
                      (should (eq increamemo-board--filter 'planned))
                      (should (equal (sort (increamemo-board-test--entry-labels tabulated-list-entries)
                                           #'string<)
                                     '("due.md" "planned.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-filter-due-shows-only-due-items ()
  "Due filter keeps only due active items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-due)
                      (should (eq increamemo-board--filter 'due))
                      (should (equal (increamemo-board-test--entry-labels tabulated-list-entries)
                                     '("due.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-filter-invalid-shows-invalid-items ()
  "Invalid filter keeps only invalid items."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-invalid)
                      (should (eq increamemo-board--filter 'invalid))
                      (should (equal (increamemo-board-test--entry-labels tabulated-list-entries)
                                     '("invalid.md"))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(ert-deftest increamemo-board-open-current-item-opens-selected-row ()
  "Opening the current board row opens the selected item."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-show-due)
                      (goto-char (point-min))
                      (search-forward "due.md")
                      (beginning-of-line)
                      (let ((opened-buffer (increamemo-board-open-current-item)))
                        (unwind-protect
                            (should (string-match-p "due.md"
                                                    (buffer-file-name opened-buffer)))
                          (when (buffer-live-p opened-buffer)
                            (kill-buffer opened-buffer)))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))))

(provide 'increamemo-board-test)
;;; increamemo-board-test.el ends here
