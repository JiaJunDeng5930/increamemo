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

(defun increamemo-board-test--goto-entry (title)
  "Move point to the row whose title column matches TITLE."
  (goto-char (point-min))
  (search-forward title)
  (beginning-of-line))

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

(ert-deftest increamemo-board-filter-all-shows-active-invalid-and-archived-items ()
  "All filter includes active, invalid, and archived items."
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
                      (increamemo-board-show-all)
                      (should (eq increamemo-board--filter 'all))
                      (should (equal (sort (increamemo-board-test--entry-labels
                                            tabulated-list-entries)
                                           #'string<)
                                     '("archived.md"
                                       "due.md"
                                       "invalid.md"
                                       "planned.md"))))
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

(ert-deftest increamemo-board-actions-update-items-and-refresh-entries ()
  "Board row actions update persistent state and refresh the table."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((root (make-temp-file "increamemo-board-" t)))
      (unwind-protect
          (progn
            (increamemo-board-test--setup-items root)
            (cl-letf (((symbol-function 'increamemo-time-today)
                       (lambda () "2026-04-21"))
                      ((symbol-function 'increamemo-time-now)
                       (lambda () "2026-04-21T09:00:00+00:00")))
              (let ((buffer (increamemo-board-open)))
                (unwind-protect
                    (with-current-buffer buffer
                      (increamemo-board-test--goto-entry "planned.md")
                      (cl-letf (((symbol-function 'read-string)
                                 (lambda (&rest _args) "2026-04-19")))
                        (increamemo-board-update-current-due-date))
                      (increamemo-board-show-due)
                      (should (equal (increamemo-board-test--entry-labels
                                      tabulated-list-entries)
                                     '("due.md" "planned.md")))
                      (increamemo-board-show-invalid)
                      (increamemo-board-show-planned)
                      (increamemo-board-test--goto-entry "planned.md")
                      (cl-letf (((symbol-function 'read-number)
                                 (lambda (&rest _args) 5)))
                        (increamemo-board-update-current-priority))
                      (should (equal (car (increamemo-board-test--entry-labels
                                           tabulated-list-entries))
                                     "planned.md"))
                      (increamemo-board-test--goto-entry "due.md")
                      (increamemo-board-archive-current-item)
                      (should-not (member "due.md"
                                          (increamemo-board-test--entry-labels
                                           tabulated-list-entries))))
                  (kill-buffer buffer)))))
        (delete-directory root t)))
    (should
     (equal
      (increamemo-test-support-select-row
       increamemo-db-file
       (concat
        "SELECT next_due_date, priority, state "
        "FROM increamemo_items WHERE title_snapshot = ?")
       '("planned.md"))
      '("2026-04-19" 5 "active")))))

(ert-deftest increamemo-board-add-item-prompts-and-refreshes ()
  "Adding an item from the board persists it and refreshes the listing."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let* ((root (make-temp-file "increamemo-board-" t))
           (manual-path (increamemo-board-test--write-note root "notes/manual.md"))
           (answers (list "file" manual-path "find-file" "2026-04-23")))
      (unwind-protect
          (cl-letf (((symbol-function 'read-string)
                     (lambda (&rest _args)
                       (prog1 (car answers)
                         (setq answers (cdr answers)))))
                    ((symbol-function 'read-number)
                     (lambda (&rest _args) 15))
                    ((symbol-function 'increamemo-time-today)
                     (lambda () "2026-04-21"))
                    ((symbol-function 'increamemo-time-now)
                     (lambda () "2026-04-21T09:00:00+00:00")))
            (let ((buffer (increamemo-board-open)))
              (unwind-protect
                  (with-current-buffer buffer
                    (increamemo-board-add-item)
                    (should (equal (increamemo-board-test--entry-labels
                                    tabulated-list-entries)
                                   '("manual.md"))))
                (kill-buffer buffer))))
        (delete-directory root t))
      (should
       (equal
        (increamemo-test-support-select-row
         increamemo-db-file
         (concat
          "SELECT type, locator, opener, next_due_date, priority "
          "FROM increamemo_items WHERE title_snapshot = ?")
         '("manual.md"))
        (list "file" manual-path "find-file" "2026-04-23" 15))))))

(provide 'increamemo-board-test)
;;; increamemo-board-test.el ends here
