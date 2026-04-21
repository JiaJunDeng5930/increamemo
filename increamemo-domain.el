;;; increamemo-domain.el --- Domain boundary for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Scheduling domain commands and validation rules.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-policy)
(require 'increamemo-storage)
(require 'increamemo-time)

(defconst increamemo-domain--date-regexp
  "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
  "Regexp used to validate ISO date strings.")

(defconst increamemo-domain--timestamp-regexp
  (concat
   "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
   "T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}"
   "[+-][0-9]\\{2\\}:[0-9]\\{2\\}\\'")
  "Regexp used to validate ISO 8601 timestamps.")

(defun increamemo-domain--db-file ()
  "Return the configured database file."
  (plist-get (increamemo-config-require-ready) :db-file))

(defun increamemo-domain--valid-date-p (value)
  "Return non-nil when VALUE is a valid ISO date string."
  (and (stringp value)
       (string-match-p increamemo-domain--date-regexp value)
       (let* ((year (string-to-number (substring value 0 4)))
              (month (string-to-number (substring value 5 7)))
              (day (string-to-number (substring value 8 10))))
         (condition-case nil
             (string= value
                      (format-time-string
                       "%F"
                       (encode-time 0 0 0 day month year nil)
                       t))
           (error nil)))))

(defun increamemo-domain--require-date (value)
  "Return VALUE when it is a valid ISO date string."
  (unless (increamemo-domain--valid-date-p value)
    (user-error "Increamemo: invalid due date: %S" value))
  value)

(defun increamemo-domain--require-timestamp (value)
  "Return VALUE when it is a valid ISO 8601 timestamp."
  (unless (and (stringp value)
               (string-match-p increamemo-domain--timestamp-regexp value))
    (user-error "Increamemo: invalid timestamp: %S" value))
  value)

(defun increamemo-domain--require-priority (value)
  "Return VALUE when it is a valid priority."
  (unless (and (integerp value)
               (<= 0 value)
               (<= value 100))
    (user-error "Increamemo: invalid priority: %S" value))
  value)

(defun increamemo-domain--serialize-opener (opener)
  "Return a serializable opener name for OPENER."
  (cond
   ((symbolp opener) (symbol-name opener))
   ((stringp opener) opener)
   (t (user-error "Increamemo: invalid opener: %S" opener))))

(defun increamemo-domain--require-source-ref (source-ref)
  "Validate SOURCE-REF and return a normalized plist."
  (let ((type (plist-get source-ref :type))
        (locator (plist-get source-ref :locator))
        (opener (plist-get source-ref :opener)))
    (unless (and (stringp type) (> (length type) 0))
      (user-error "Increamemo: invalid source type: %S" type))
    (unless (and (stringp locator) (> (length locator) 0))
      (user-error "Increamemo: invalid locator: %S" locator))
    (list :type type
          :locator locator
          :opener (increamemo-domain--serialize-opener opener)
          :title-snapshot (plist-get source-ref :title-snapshot)
          :custom-json (plist-get source-ref :custom-json))))

(defun increamemo-domain--occurred-at-date (occurred-at)
  "Return the ISO date part of OCCURRED-AT."
  (substring occurred-at 0 10))

(defun increamemo-domain--resolve-initial-due-date
    (source-ref priority due-date occurred-at)
  "Return the initial due date for SOURCE-REF.

PRIORITY and OCCURRED-AT are passed to the optional configured strategy.
When DUE-DATE is non-nil, validate and return it."
  (if due-date
      (increamemo-domain--require-date due-date)
    (let ((today (increamemo-domain--occurred-at-date occurred-at)))
      (if increamemo-initial-due-date-function
          (increamemo-domain--require-date
           (funcall increamemo-initial-due-date-function
                    source-ref
                    priority
                    today
                    occurred-at))
        today))))

(defun increamemo-domain--row-to-item (row)
  "Convert database ROW into an item plist."
  (when row
    (list :id (nth 0 row)
          :type (nth 1 row)
          :locator (nth 2 row)
          :opener (nth 3 row)
          :title-snapshot (nth 4 row)
          :next-due-date (nth 5 row)
          :priority (nth 6 row)
          :state (nth 7 row)
          :created-at (nth 8 row)
          :updated-at (nth 9 row)
          :last-reviewed-at (nth 10 row)
          :last-error (nth 11 row)
          :custom-json (nth 12 row)
          :version (nth 13 row))))

(defun increamemo-domain--select-item-row (connection item-id)
  "Return the item row for ITEM-ID on CONNECTION."
  (car
   (increamemo-storage-select
    connection
    (concat
     "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
     "priority, state, created_at, updated_at, last_reviewed_at, "
     "last_error, custom_json, version "
     "FROM increamemo_items WHERE id = ?")
    (list item-id))))

(defun increamemo-domain--timestamp-date (timestamp)
  "Return the ISO date portion of TIMESTAMP, or nil when absent."
  (when timestamp
    (substring timestamp 0 10)))

(defun increamemo-domain--days-between (start-date end-date)
  "Return whole days between START-DATE and END-DATE."
  (let* ((start-time (date-to-time (concat start-date " 00:00:00 +0000")))
         (end-time (date-to-time (concat end-date " 00:00:00 +0000"))))
    (floor (/ (float-time (time-subtract end-time start-time)) 86400))))

(defun increamemo-domain--history-summary (connection item-id &optional row)
  "Return a summary plist for ITEM-ID from CONNECTION.

When ROW is provided, enrich the summary with current item facts."
  (let* ((current-row (or row (increamemo-domain--select-item-row connection item-id)))
         (last-reviewed-at (and current-row (nth 10 current-row)))
         (next-due-date (and current-row (nth 5 current-row)))
         (last-reviewed-date
          (increamemo-domain--timestamp-date last-reviewed-at)))
    (list
     :history-count
     (or
      (increamemo-storage-select-value
       connection
       "SELECT COUNT(*) FROM increamemo_history WHERE item_id = ?"
       (list item-id))
      0)
     :completed-count
     (or
      (increamemo-storage-select-value
       connection
       (concat
        "SELECT COUNT(*) FROM increamemo_history "
        "WHERE item_id = ? AND action = 'completed'")
       (list item-id))
      0)
     :last-completed-at
     (increamemo-storage-select-value
      connection
      (concat
       "SELECT occurred_at FROM increamemo_history "
       "WHERE item_id = ? AND action = 'completed' "
       "ORDER BY occurred_at DESC LIMIT 1")
      (list item-id))
     :last-occurred-at
     (increamemo-storage-select-value
      connection
      (concat
       "SELECT occurred_at FROM increamemo_history "
       "WHERE item_id = ? ORDER BY occurred_at DESC LIMIT 1")
      (list item-id))
     :last-reviewed-at last-reviewed-at
     :current-interval-days
     (when (and last-reviewed-date next-due-date)
       (increamemo-domain--days-between last-reviewed-date next-due-date)))))

(defun increamemo-domain--require-advanced-version
    (connection item-id previous-version)
  "Return ITEM-ID row after PREVIOUS-VERSION advances on CONNECTION.

Signal `user-error' when the guarded write did not advance the row version."
  (let ((row (increamemo-domain--select-item-row connection item-id)))
    (unless (and row
                 (= (nth 13 row) (1+ previous-version)))
      (user-error "Increamemo: version conflict for item %s" item-id))
    row))

(defun increamemo-domain--find-live-duplicate-row (connection type locator)
  "Return the active or invalid row on CONNECTION for TYPE and LOCATOR."
  (car
   (increamemo-storage-select
    connection
    (concat
     "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
     "priority, state, created_at, updated_at, last_reviewed_at, "
     "last_error, custom_json, version "
     "FROM increamemo_items "
     "WHERE type = ? AND locator = ? AND state IN ('active', 'invalid') "
     "LIMIT 1")
    (list type locator))))

(defun increamemo-domain--insert-history
    (connection item-id action occurred-at
                previous-state new-state
                previous-due-date new-due-date
                previous-priority new-priority)
  "Insert a history row on CONNECTION for ITEM-ID.

ACTION identifies the history entry.
OCCURRED-AT records when ACTION happened.
PREVIOUS-STATE and NEW-STATE describe the state transition.
PREVIOUS-DUE-DATE and NEW-DUE-DATE describe the due-date transition.
PREVIOUS-PRIORITY and NEW-PRIORITY describe the priority transition."
  (increamemo-storage-execute
   connection
   (concat
    "INSERT INTO increamemo_history("
    "item_id, action, occurred_at, previous_state, new_state, "
    "previous_due_date, new_due_date, previous_priority, new_priority"
    ") VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)")
   (list item-id action occurred-at
         previous-state new-state
         previous-due-date new-due-date
         previous-priority new-priority)))

(defun increamemo-domain--update-item
    (item-id occurred-at action
             updater allowed-states)
  "Update ITEM-ID at OCCURRED-AT with ACTION using UPDATER.

UPDATER receives the current row and returns a plist with keys
`:sql', `:values', `:previous-state', `:new-state', `:previous-due-date',
`:new-due-date', `:previous-priority', and `:new-priority'.
ACTION names the history operation.
ALLOWED-STATES defines which current states may apply ACTION."
  (let ((db-file (increamemo-domain--db-file)))
    (let ((connection (increamemo-storage-open db-file)))
      (unwind-protect
          (increamemo-storage-with-transaction connection
            (let* ((row (or (increamemo-domain--select-item-row connection item-id)
                            (user-error "Increamemo: item %s does not exist"
                                        item-id)))
                   (state (nth 7 row)))
              (unless (memq (intern state) allowed-states)
                (user-error
                 "Increamemo: item %s does not allow action %s from %s"
                 item-id action state))
              (let* ((changes (funcall updater row))
                     (sql (plist-get changes :sql))
                     (values (plist-get changes :values))
                     (updated-row nil))
                (increamemo-storage-execute connection sql values)
                (setq updated-row
                      (increamemo-domain--require-advanced-version
                       connection
                       item-id
                       (nth 13 row)))
                (increamemo-domain--insert-history
                 connection
                 item-id
                 action
                 occurred-at
                 (plist-get changes :previous-state)
                 (plist-get changes :new-state)
                 (plist-get changes :previous-due-date)
                 (plist-get changes :new-due-date)
                 (plist-get changes :previous-priority)
                 (plist-get changes :new-priority))
                (increamemo-domain--row-to-item updated-row))))
        (increamemo-storage-close connection)))))

(defun increamemo-domain-ensure-item
    (source-ref priority due-date &optional occurred-at)
  "Ensure SOURCE-REF exists as an active item with PRIORITY and DUE-DATE.

When OCCURRED-AT is nil, use the current timestamp."
  (let* ((normalized-source (increamemo-domain--require-source-ref source-ref))
         (validated-priority (increamemo-domain--require-priority priority))
         (validated-occurred-at
          (increamemo-domain--require-timestamp
           (or occurred-at (increamemo-time-now))))
         (validated-due-date
          (increamemo-domain--resolve-initial-due-date
           normalized-source
           validated-priority
           due-date
           validated-occurred-at))
         (db-file (increamemo-domain--db-file)))
    (let ((connection (increamemo-storage-open db-file)))
      (unwind-protect
          (or (increamemo-domain--row-to-item
               (increamemo-domain--find-live-duplicate-row
                connection
                (plist-get normalized-source :type)
                (plist-get normalized-source :locator)))
              (increamemo-storage-with-transaction connection
                (increamemo-storage-execute
                 connection
                 (concat
                  "INSERT INTO increamemo_items("
                  "type, locator, opener, title_snapshot, next_due_date, "
                  "priority, state, created_at, updated_at, custom_json"
                  ") VALUES(?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)")
                 (list (plist-get normalized-source :type)
                       (plist-get normalized-source :locator)
                       (plist-get normalized-source :opener)
                       (plist-get normalized-source :title-snapshot)
                       validated-due-date
                       validated-priority
                       validated-occurred-at
                       validated-occurred-at
                       (plist-get normalized-source :custom-json)))
                (let ((item-id
                       (increamemo-storage-select-value
                        connection
                        "SELECT last_insert_rowid()")))
                  (increamemo-domain--insert-history
                   connection
                   item-id
                   "created"
                   validated-occurred-at
                   nil
                   "active"
                   nil
                   validated-due-date
                   nil
                   validated-priority)
                  (increamemo-domain--row-to-item
                   (increamemo-domain--select-item-row connection item-id)))))
        (increamemo-storage-close connection)))))

(defun increamemo-domain-list-due (today &optional excluded-item-ids)
  "Return active due items for TODAY excluding EXCLUDED-ITEM-IDS."
  (let* ((validated-today (increamemo-domain--require-date today))
         (db-file (increamemo-domain--db-file))
         (excluded-values (or excluded-item-ids '()))
         (placeholders
          (mapconcat (lambda (_value) "?") excluded-values ", "))
         (sql
          (concat
           "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
           "priority, state, created_at, updated_at, last_reviewed_at, "
           "last_error, custom_json, version "
           "FROM increamemo_items "
           "WHERE state = 'active' AND next_due_date <= ?"
           (if excluded-values
               (format " AND id NOT IN (%s)" placeholders)
             "")
           " ORDER BY priority ASC, next_due_date ASC, created_at ASC")))
    (let ((connection (increamemo-storage-open db-file)))
      (unwind-protect
          (mapcar
           #'increamemo-domain--row-to-item
           (increamemo-storage-select
            connection
            sql
            (cons validated-today excluded-values)))
        (increamemo-storage-close connection)))))

(defun increamemo-domain-list-planned (&optional filter today)
  "Return planned items for FILTER using TODAY when needed.

FILTER accepts `planned', `due', `invalid', and `all'."
  (let* ((effective-filter (or filter 'planned))
         (validated-today (and today (increamemo-domain--require-date today)))
         (db-file (increamemo-domain--db-file))
         (query
          (pcase effective-filter
            ('planned
             (concat
              "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
              "priority, state, created_at, updated_at, last_reviewed_at, "
              "last_error, custom_json, version "
              "FROM increamemo_items "
              "WHERE state = 'active' AND next_due_date IS NOT NULL "
              "ORDER BY priority ASC, next_due_date ASC, created_at ASC"))
            ('due
             (unless validated-today
               (user-error "Increamemo: today is required for due filter"))
             (concat
              "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
              "priority, state, created_at, updated_at, last_reviewed_at, "
              "last_error, custom_json, version "
              "FROM increamemo_items "
              "WHERE state = 'active' AND next_due_date <= ? "
              "ORDER BY priority ASC, next_due_date ASC, created_at ASC"))
            ('invalid
             (concat
              "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
              "priority, state, created_at, updated_at, last_reviewed_at, "
              "last_error, custom_json, version "
              "FROM increamemo_items "
              "WHERE state = 'invalid' "
              "ORDER BY priority ASC, next_due_date ASC, created_at ASC"))
            ('all
             (concat
              "SELECT id, type, locator, opener, title_snapshot, next_due_date, "
              "priority, state, created_at, updated_at, last_reviewed_at, "
              "last_error, custom_json, version "
              "FROM increamemo_items "
              "ORDER BY state ASC, priority ASC, next_due_date ASC, created_at ASC"))
            (_
             (user-error "Increamemo: unsupported board filter: %S"
                         effective-filter))))
         (values (if (eq effective-filter 'due)
                     (list validated-today)
                   nil)))
    (let ((connection (increamemo-storage-open db-file)))
      (unwind-protect
          (mapcar #'increamemo-domain--row-to-item
                  (increamemo-storage-select connection query values))
        (increamemo-storage-close connection)))))

(defun increamemo-domain-archive-item (item-id &optional occurred-at)
  "Archive ITEM-ID and append an archived history row.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now)))))
    (let* ((db-file (increamemo-domain--db-file))
           (connection (increamemo-storage-open db-file)))
      (unwind-protect
          (let ((row (or (increamemo-domain--select-item-row connection item-id)
                         (user-error "Increamemo: item %s does not exist"
                                     item-id))))
            (if (equal (nth 7 row) "archived")
                (increamemo-domain--row-to-item row)
              (increamemo-domain--update-item
               item-id
               validated-occurred-at
               "archived"
               (lambda (current-row)
                 (let ((version (nth 13 current-row))
                       (state (nth 7 current-row)))
                   (list :sql
                         (concat
                          "UPDATE increamemo_items "
                          "SET state = 'archived', updated_at = ?, version = version + 1 "
                          "WHERE id = ? AND version = ?")
                         :values (list validated-occurred-at item-id version)
                         :previous-state state
                         :new-state "archived"
                         :previous-due-date (nth 5 current-row)
                         :new-due-date (nth 5 current-row)
                         :previous-priority (nth 6 current-row)
                         :new-priority (nth 6 current-row))))
               '(active invalid))))
        (increamemo-storage-close connection)))))

(defun increamemo-domain-defer-item (item-id new-due-date &optional occurred-at)
  "Update ITEM-ID with NEW-DUE-DATE and append a deferred history row.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-due-date (increamemo-domain--require-date new-due-date))
        (validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now)))))
    (increamemo-domain--update-item
     item-id
     validated-occurred-at
     "deferred"
     (lambda (row)
       (let ((version (nth 13 row)))
         (list :sql
               (concat
                "UPDATE increamemo_items "
                "SET next_due_date = ?, updated_at = ?, version = version + 1 "
                "WHERE id = ? AND version = ?")
               :values (list validated-due-date
                             validated-occurred-at
                             item-id
                             version)
               :previous-state (nth 7 row)
               :new-state (nth 7 row)
               :previous-due-date (nth 5 row)
               :new-due-date validated-due-date
               :previous-priority (nth 6 row)
               :new-priority (nth 6 row))))
     '(active))))

(defun increamemo-domain-update-priority
    (item-id priority &optional occurred-at)
  "Update ITEM-ID with PRIORITY and append a history row.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-priority (increamemo-domain--require-priority priority))
        (validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now)))))
    (increamemo-domain--update-item
     item-id
     validated-occurred-at
     "priority_changed"
     (lambda (row)
       (let ((version (nth 13 row)))
         (list :sql
               (concat
                "UPDATE increamemo_items "
                "SET priority = ?, updated_at = ?, version = version + 1 "
                "WHERE id = ? AND version = ?")
               :values (list validated-priority
                             validated-occurred-at
                             item-id
                             version)
               :previous-state (nth 7 row)
               :new-state (nth 7 row)
               :previous-due-date (nth 5 row)
               :new-due-date (nth 5 row)
               :previous-priority (nth 6 row)
               :new-priority validated-priority)))
     '(active invalid archived))))

(defun increamemo-domain-update-due-date
    (item-id due-date &optional occurred-at)
  "Update ITEM-ID with DUE-DATE.

When OCCURRED-AT is nil, use the current timestamp."
  (increamemo-domain-defer-item item-id due-date occurred-at))

(defun increamemo-domain-skip-item (item-id &optional occurred-at)
  "Record a skip action for ITEM-ID without changing its schedule.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now)))))
    (increamemo-domain--update-item
     item-id
     validated-occurred-at
     "skipped"
     (lambda (row)
       (let ((version (nth 13 row)))
         (list :sql
               (concat
                "UPDATE increamemo_items "
                "SET updated_at = ?, version = version + 1 "
                "WHERE id = ? AND version = ?")
               :values (list validated-occurred-at item-id version)
               :previous-state (nth 7 row)
               :new-state (nth 7 row)
               :previous-due-date (nth 5 row)
               :new-due-date (nth 5 row)
               :previous-priority (nth 6 row)
               :new-priority (nth 6 row))))
     '(active))))

(defun increamemo-domain-record-open-failure
    (item-id error-message &optional occurred-at)
  "Record an open failure for ITEM-ID with ERROR-MESSAGE.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now)))))
    (increamemo-domain--update-item
     item-id
     validated-occurred-at
     "open_failed"
     (lambda (row)
       (let ((version (nth 13 row)))
         (list :sql
               (concat
                "UPDATE increamemo_items "
                "SET last_error = ?, updated_at = ?, version = version + 1 "
                "WHERE id = ? AND version = ?")
               :values (list error-message
                             validated-occurred-at
                             item-id
                             version)
               :previous-state (nth 7 row)
               :new-state (nth 7 row)
               :previous-due-date (nth 5 row)
               :new-due-date (nth 5 row)
               :previous-priority (nth 6 row)
               :new-priority (nth 6 row))))
     '(active invalid))))

(defun increamemo-domain-mark-invalid
    (item-id error-message &optional occurred-at)
  "Mark ITEM-ID invalid with ERROR-MESSAGE.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now)))))
    (increamemo-domain--update-item
     item-id
     validated-occurred-at
     "open_failed"
     (lambda (row)
       (let ((version (nth 13 row)))
         (list :sql
               (concat
                "UPDATE increamemo_items "
                "SET state = 'invalid', last_error = ?, "
                "updated_at = ?, version = version + 1 "
                "WHERE id = ? AND version = ?")
               :values (list error-message
                             validated-occurred-at
                             item-id
                             version)
               :previous-state (nth 7 row)
               :new-state "invalid"
               :previous-due-date (nth 5 row)
               :new-due-date (nth 5 row)
               :previous-priority (nth 6 row)
               :new-priority (nth 6 row))))
     '(active invalid))))

(defun increamemo-domain-delete-item (item-id &optional occurred-at)
  "Delete ITEM-ID from the schedule.

When OCCURRED-AT is nil, use the current timestamp."
  (let ((validated-occurred-at
         (increamemo-domain--require-timestamp
          (or occurred-at (increamemo-time-now))))
        (db-file (increamemo-domain--db-file)))
    (let ((connection (increamemo-storage-open db-file)))
      (unwind-protect
          (increamemo-storage-with-transaction connection
            (let ((row (increamemo-domain--select-item-row connection item-id)))
              (if (null row)
                  (list :status 'deleted :item nil)
                (progn
                  (increamemo-domain--insert-history
                   connection
                   item-id
                   "deleted"
                   validated-occurred-at
                   (nth 7 row)
                   nil
                   (nth 5 row)
                   nil
                   (nth 6 row)
                   nil)
                  (increamemo-storage-execute
                   connection
                   "DELETE FROM increamemo_items WHERE id = ?"
                   (list item-id))
                  (list :status 'deleted
                        :item (increamemo-domain--row-to-item row)
                        :occurred-at validated-occurred-at)))))
        (increamemo-storage-close connection)))))

(defun increamemo-domain-complete-current
    (item-id today &optional occurred-at)
  "Complete ITEM-ID for TODAY.

When OCCURRED-AT is nil, use the current timestamp."
  (let* ((validated-today (increamemo-domain--require-date today))
         (validated-occurred-at
          (increamemo-domain--require-timestamp
           (or occurred-at (increamemo-time-now))))
         (db-file (increamemo-domain--db-file))
         (connection (increamemo-storage-open db-file)))
    (unwind-protect
        (let ((row (or (increamemo-domain--select-item-row connection item-id)
                       (user-error "Increamemo: item %s does not exist"
                                   item-id))))
          (unless (equal (nth 7 row) "active")
            (user-error "Increamemo: item %s is not active" item-id))
          (if (string< validated-today (nth 5 row))
              (list :status 'stale
                    :item (increamemo-domain--row-to-item row))
            (let* ((item (increamemo-domain--row-to-item row))
                   (history-summary
                    (increamemo-domain--history-summary connection item-id row))
                   (new-due-date
                    (increamemo-policy-compute-next-due-date
                     item
                     'complete
                     history-summary
                     validated-today)))
              (increamemo-storage-with-transaction connection
                (increamemo-storage-execute
                 connection
                 (concat
                  "UPDATE increamemo_items "
                  "SET next_due_date = ?, last_reviewed_at = ?, "
                  "updated_at = ?, version = version + 1 "
                  "WHERE id = ? AND version = ?")
                 (list new-due-date
                       validated-occurred-at
                       validated-occurred-at
                       item-id
                       (nth 13 row)))
                (let ((updated-row
                       (increamemo-domain--require-advanced-version
                        connection
                        item-id
                        (nth 13 row))))
                (increamemo-domain--insert-history
                 connection
                 item-id
                 "completed"
                 validated-occurred-at
                 "active"
                 "active"
                 (nth 5 row)
                 new-due-date
                 (nth 6 row)
                 (nth 6 row))
                  (list
                   :status 'completed
                   :item (increamemo-domain--row-to-item updated-row)))))))
      (increamemo-storage-close connection))))

(provide 'increamemo-domain)
;;; increamemo-domain.el ends here
