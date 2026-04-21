;;; increamemo-migration.el --- Schema management for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Database initialization and schema version control.

;;; Code:

(require 'increamemo-config)
(require 'increamemo-storage)

(defconst increamemo-migration-schema-version "1"
  "Current increamemo schema version.")

(defconst increamemo-migration--schema-statements
  '("CREATE TABLE IF NOT EXISTS increamemo_meta (
       key TEXT PRIMARY KEY,
       value TEXT NOT NULL
     )"
    "CREATE TABLE IF NOT EXISTS increamemo_items (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       type TEXT NOT NULL,
       locator TEXT NOT NULL,
       opener TEXT NOT NULL,
       title_snapshot TEXT,
       next_due_date TEXT NOT NULL,
       priority INTEGER NOT NULL,
       state TEXT NOT NULL,
       created_at TEXT NOT NULL,
       updated_at TEXT NOT NULL,
       last_reviewed_at TEXT,
       last_error TEXT,
       custom_json TEXT,
       version INTEGER NOT NULL DEFAULT 0
     )"
    "CREATE TABLE IF NOT EXISTS increamemo_history (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       item_id INTEGER NOT NULL,
       action TEXT NOT NULL,
       occurred_at TEXT NOT NULL,
       previous_state TEXT,
       new_state TEXT,
       previous_due_date TEXT,
       new_due_date TEXT,
       previous_priority INTEGER,
       new_priority INTEGER,
       payload_json TEXT,
       FOREIGN KEY(item_id) REFERENCES increamemo_items(id)
     )"
    "CREATE INDEX IF NOT EXISTS increamemo_items_due_idx
       ON increamemo_items(state, next_due_date, priority, created_at)"
    "CREATE UNIQUE INDEX IF NOT EXISTS increamemo_items_live_locator_idx
       ON increamemo_items(type, locator)
       WHERE state IN ('active', 'invalid')")
  "Statements required for the initial schema.")

(defconst increamemo-migration--upgrade-steps
  '(("0" . increamemo-migration--upgrade-from-0))
  "Migration functions keyed by their source schema version.")

(defun increamemo-migration--table-exists-p (connection table-name)
  "Return non-nil when TABLE-NAME exists on CONNECTION."
  (increamemo-storage-select-value
   connection
   "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"
   (list table-name)))

(defun increamemo-migration--schema-version (connection)
  "Return schema version recorded on CONNECTION."
  (when (increamemo-migration--table-exists-p connection "increamemo_meta")
    (increamemo-storage-select-value
     connection
     "SELECT value FROM increamemo_meta WHERE key = ?"
     '("schema-version"))))

(defun increamemo-migration--set-schema-version (connection version)
  "Persist VERSION in the schema metadata table on CONNECTION."
  (increamemo-storage-execute
   connection
   (concat
    "INSERT INTO increamemo_meta(key, value) VALUES(?, ?) "
    "ON CONFLICT(key) DO UPDATE SET value = excluded.value")
   (list "schema-version" version)))

(defun increamemo-migration--ensure-current-schema (connection)
  "Ensure the current schema exists on CONNECTION."
  (increamemo-storage-with-transaction connection
    (dolist (statement increamemo-migration--schema-statements)
      (increamemo-storage-execute connection statement))
    (increamemo-migration--set-schema-version
     connection
     increamemo-migration-schema-version)))

(defun increamemo-migration--upgrade-from-0 (connection)
  "Upgrade schema version 0 on CONNECTION to the current version."
  (increamemo-migration--ensure-current-schema connection))

(defun increamemo-migration--upgrade-schema (connection version)
  "Upgrade schema VERSION on CONNECTION to the current version."
  (let ((current-version version))
    (while (not (string= current-version increamemo-migration-schema-version))
      (let ((step (assoc current-version increamemo-migration--upgrade-steps)))
        (unless step
          (user-error
           "Increamemo: schema version %s is unsupported"
           current-version))
        (funcall (cdr step) connection)
        (setq current-version
              (increamemo-migration--schema-version connection))))))

(defun increamemo-migration-initialize ()
  "Ensure the database schema exists and matches the current version."
  (let* ((db-file (plist-get (increamemo-config-require-ready) :db-file))
         (db-dir (file-name-directory db-file)))
    (when db-dir
      (make-directory db-dir t))
    (let ((connection (increamemo-storage-open db-file)))
      (unwind-protect
          (let ((version (increamemo-migration--schema-version connection)))
            (cond
             ((null version)
              (increamemo-migration--ensure-current-schema connection))
             ((string= version increamemo-migration-schema-version)
              db-file)
             ((< (string-to-number version)
                 (string-to-number increamemo-migration-schema-version))
              (increamemo-migration--upgrade-schema connection version))
             (t
              (user-error
               "Increamemo: schema version %s is unsupported"
               version))))
        (increamemo-storage-close connection)))))

(provide 'increamemo-migration)
;;; increamemo-migration.el ends here
