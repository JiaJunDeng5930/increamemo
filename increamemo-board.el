;;; increamemo-board.el --- Board runtime for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Board runtime and tabulated list presentation.

;;; Code:

(require 'cl-lib)
(require 'increamemo-config)
(require 'increamemo-domain)
(require 'increamemo-failure)
(require 'increamemo-opener)
(require 'increamemo-time)
(require 'tabulated-list)

(defconst increamemo-board-buffer-name "*Increamemo Board*"
  "Name of the board buffer.")

(defvar-local increamemo-board--filter 'planned
  "Current board filter.")

(defvar-local increamemo-board--items nil
  "Current board item snapshots keyed by id.")

(defvar increamemo-board-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "a") #'increamemo-board-add-item)
    (define-key map (kbd "A") #'increamemo-board-archive-current-item)
    (define-key map (kbd "d") #'increamemo-board-update-current-due-date)
    (define-key map (kbd "p") #'increamemo-board-update-current-priority)
    (define-key map (kbd "t") #'increamemo-board-show-due)
    (define-key map (kbd "i") #'increamemo-board-show-invalid)
    (define-key map (kbd "g") #'increamemo-board-refresh)
    (define-key map (kbd "RET") #'increamemo-board-open-current-item)
    (define-key map (kbd "q") #'increamemo-board-quit)
    map)
  "Keymap for `increamemo-board-mode'.")

(defun increamemo-board--format-item (item)
  "Return the tabulated list entry for ITEM."
  (let ((id (plist-get item :id)))
    (list
     id
     (vector
      (plist-get item :type)
      (or (plist-get item :next-due-date) "")
      (number-to-string (plist-get item :priority))
      (plist-get item :state)
      (plist-get item :opener)
      (or (plist-get item :title-snapshot) "")
      (plist-get item :locator)))))

(defun increamemo-board--today ()
  "Return today's date for board filtering."
  (increamemo-time-today))

(defun increamemo-board--current-item ()
  "Return the item snapshot for the current board row."
  (let ((item-id (tabulated-list-get-id)))
    (alist-get item-id increamemo-board--items)))

(defun increamemo-board--current-item-required ()
  "Return the current board item or raise `user-error'."
  (or (increamemo-board--current-item)
      (user-error "Increamemo: no board item on the current line")))

(defun increamemo-board--current-live-item-required ()
  "Return the current board item after a fresh domain read."
  (let* ((stale-item (increamemo-board--current-item-required))
         (item-id (plist-get stale-item :id))
         (live-item
          (cl-find-if
           (lambda (item)
             (= (plist-get item :id) item-id))
           (increamemo-domain-list-planned 'all (increamemo-board--today)))))
    (or live-item
        (user-error "Increamemo: item %s does not exist" item-id))))

(defun increamemo-board--missing-item-error-p (err)
  "Return non-nil when ERR reports a missing scheduled item."
  (and (eq (car err) 'user-error)
       (string-match-p
        "\\`Increamemo: item [0-9]+ does not exist\\'"
        (error-message-string err))))

(defun increamemo-board--call-with-missing-item-refresh (thunk)
  "Call THUNK and refresh the board when its row item is already missing."
  (condition-case err
      (funcall thunk)
    (user-error
     (if (increamemo-board--missing-item-error-p err)
         (progn
           (message "%s" (error-message-string err))
           (increamemo-board-refresh)
           nil)
       (signal (car err) (cdr err))))))

(defun increamemo-board--normalize-locator (type locator)
  "Return a normalized LOCATOR for TYPE."
  (if (string= type "file")
      (expand-file-name locator)
    locator))

(defun increamemo-board--title-snapshot (type locator)
  "Return a title snapshot for TYPE and LOCATOR."
  (if (string= type "file")
      (file-name-nondirectory locator)
    locator))

(defun increamemo-board-refresh ()
  "Refresh the board entries for the current filter."
  (interactive)
  (increamemo-config-require-ready)
  (let* ((items
          (increamemo-domain-list-planned
           increamemo-board--filter
           (increamemo-board--today)))
         (entries (mapcar #'increamemo-board--format-item items)))
    (setq increamemo-board--items
          (mapcar (lambda (item)
                    (cons (plist-get item :id) item))
                  items))
    (setq tabulated-list-entries entries)
    (tabulated-list-print t)))

(defun increamemo-board-show-due ()
  "Switch the board to the due filter."
  (interactive)
  (increamemo-config-require-ready)
  (setq increamemo-board--filter 'due)
  (increamemo-board-refresh))

(defun increamemo-board-show-planned ()
  "Switch the board to the planned filter."
  (interactive)
  (increamemo-config-require-ready)
  (setq increamemo-board--filter 'planned)
  (increamemo-board-refresh))

(defun increamemo-board-show-invalid ()
  "Switch the board to the invalid filter."
  (interactive)
  (increamemo-config-require-ready)
  (setq increamemo-board--filter 'invalid)
  (increamemo-board-refresh))

(defun increamemo-board-show-all ()
  "Switch the board to the all-items filter."
  (interactive)
  (increamemo-config-require-ready)
  (setq increamemo-board--filter 'all)
  (increamemo-board-refresh))

(defun increamemo-board-add-item ()
  "Prompt for item fields, persist the item, and refresh the board."
  (interactive)
  (increamemo-config-require-ready)
  (let* ((type (read-string "Type: "))
         (locator-input (read-string "Locator: "))
         (locator (increamemo-board--normalize-locator type locator-input))
         (opener (read-string "Opener: "))
         (priority (read-number "Priority: "))
         (due-date (read-string "Due date: ")))
    (increamemo-domain-ensure-item
     (list :type type
           :locator locator
           :opener opener
           :title-snapshot (increamemo-board--title-snapshot type locator))
     priority
     due-date
     (increamemo-time-now))
    (increamemo-board-refresh)))

(defun increamemo-board-archive-current-item ()
  "Archive the current board row item and refresh."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-board--call-with-missing-item-refresh
   (lambda ()
     (increamemo-domain-archive-item
      (plist-get (increamemo-board--current-live-item-required) :id)
      (increamemo-time-now))
     (increamemo-board-refresh))))

(defun increamemo-board-update-current-due-date ()
  "Update the due date for the current board row item."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-board--call-with-missing-item-refresh
   (lambda ()
     (let ((item (increamemo-board--current-live-item-required)))
       (increamemo-domain-update-due-date
        (plist-get item :id)
        (read-string "Due date: " (plist-get item :next-due-date))
        (increamemo-time-now))
       (increamemo-board-refresh)))))

(defun increamemo-board-update-current-priority ()
  "Update the priority for the current board row item."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-board--call-with-missing-item-refresh
   (lambda ()
     (let ((item (increamemo-board--current-live-item-required)))
       (increamemo-domain-update-priority
        (plist-get item :id)
        (read-number "Priority: " (plist-get item :priority))
        (increamemo-time-now))
       (increamemo-board-refresh)))))

(defun increamemo-board-open-current-item ()
  "Open the current board row item."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-board--call-with-missing-item-refresh
   (lambda ()
     (let ((item (increamemo-board--current-live-item-required)))
       (condition-case err
           (increamemo-opener-open-item item)
         (increamemo-opener-error
          (message
           "Increamemo: failed to open item #%s: %s"
           (plist-get item :id)
           (plist-get (car (cdr err)) :message))
          (increamemo-failure-handle-open-error
           item
           err
           (increamemo-time-now))
          (increamemo-board-refresh)
          nil))))))

(defun increamemo-board-quit ()
  "Quit the board buffer."
  (interactive)
  (quit-window t (selected-window)))

(define-derived-mode increamemo-board-mode tabulated-list-mode "Increamemo Board"
  "Major mode for the increamemo board."
  (setq tabulated-list-format
        [("Type" 12 t)
         ("Due Date" 12 t)
         ("Priority" 10 t)
         ("State" 10 t)
         ("Opener" 20 t)
         ("Title" 24 t)
         ("Locator" 32 t)])
  (setq tabulated-list-padding 2)
  (setq increamemo-board--filter 'planned)
  (setq increamemo-board--items nil)
  (tabulated-list-init-header))

(defun increamemo-board-open ()
  "Open the board buffer."
  (interactive)
  (increamemo-config-require-ready)
  (let ((buffer (get-buffer-create increamemo-board-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'increamemo-board-mode)
        (increamemo-board-mode))
      (increamemo-board-refresh))
    (pop-to-buffer buffer)
    buffer))

(provide 'increamemo-board)
;;; increamemo-board.el ends here
