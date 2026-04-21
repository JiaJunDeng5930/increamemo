;;; increamemo-work-test.el --- Work session tests -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression tests for the work session runtime.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'increamemo)
(require 'increamemo-domain)
(require 'increamemo-test-support)
(require 'increamemo-work)

(defun increamemo-work-test--source-ref (path)
  "Return a file source ref for PATH."
  (list :type "file"
        :locator path
        :opener 'find-file
        :title-snapshot (file-name-nondirectory path)))

(ert-deftest increamemo-work-start-opens-first-due-item-and-enables-mode ()
  "Starting work opens the first due item and enables work mode."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-test-support-with-file-buffer "notes/low.md" "low"
      (let ((low-path (expand-file-name buffer-file-name)))
        (increamemo-domain-ensure-item
         (increamemo-work-test--source-ref low-path)
         50
         "2026-04-21"
         "2026-04-21T08:00:00+00:00")))
    (increamemo-test-support-with-file-buffer "notes/high.md" "high"
      (let* ((high-path (expand-file-name buffer-file-name))
             (high-item
              (increamemo-domain-ensure-item
               (increamemo-work-test--source-ref high-path)
               10
               "2026-04-21"
               "2026-04-21T08:01:00+00:00")))
        (cl-letf (((symbol-function 'increamemo-time-today)
                   (lambda () "2026-04-21")))
          (let ((opened-buffer (increamemo-work-start)))
            (unwind-protect
                (with-current-buffer opened-buffer
                  (should increamemo-work-mode)
                  (should (= increamemo-work--current-item-id
                             (plist-get high-item :id)))
                  (should (equal (buffer-file-name)
                                 high-path))
                  (should (equal (increamemo-work--mode-line-text)
                                 "IM[0/2]")))
              (increamemo-work-quit)
              (when (buffer-live-p opened-buffer)
                (kill-buffer opened-buffer)))))))))

(ert-deftest increamemo-work-start-shows-message-when-no-due-items ()
  "Starting work shows a message and does not keep a session when nothing is due."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (let ((captured-message nil))
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21"))
                ((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (setq captured-message
                         (apply #'format format-string args)))))
        (should-not (increamemo-work-start))
        (should (equal captured-message "Increamemo: no due items"))
        (should-not increamemo-work--session)))))

(ert-deftest increamemo-work-quit-clears-session-state ()
  "Quitting work disables the mode and clears the active session."
  (increamemo-test-support-with-temp-db
    (increamemo-init)
    (increamemo-test-support-with-file-buffer "notes/topic.md" "topic"
      (let ((path (expand-file-name buffer-file-name)))
        (increamemo-domain-ensure-item
         (increamemo-work-test--source-ref path)
         10
         "2026-04-21"
         "2026-04-21T08:00:00+00:00"))
      (cl-letf (((symbol-function 'increamemo-time-today)
                 (lambda () "2026-04-21")))
        (let ((opened-buffer (increamemo-work-start)))
          (with-current-buffer opened-buffer
            (increamemo-work-quit)
            (should-not increamemo-work-mode)
            (should-not increamemo-work--current-item-id)
            (should-not increamemo-work--session-id))
          (should-not increamemo-work--session)
          (when (buffer-live-p opened-buffer)
            (kill-buffer opened-buffer)))))))

(provide 'increamemo-work-test)
;;; increamemo-work-test.el ends here
