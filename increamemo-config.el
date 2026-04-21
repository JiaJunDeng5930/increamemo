;;; increamemo-config.el --- Configuration for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; User-facing configuration and readiness checks.

;;; Code:

(defgroup increamemo nil
  "Scheduled note review workflows."
  :group 'applications)

(defcustom increamemo-db-file nil
  "SQLite database file used by increamemo."
  :type '(choice (const :tag "Unset" nil) file)
  :group 'increamemo)

(defcustom increamemo-supported-file-formats '("md" "org" "txt")
  "Supported file extensions for file-backed items."
  :type '(repeat string)
  :group 'increamemo)

(defcustom increamemo-file-openers
  '(("md" . find-file)
    ("org" . find-file)
    ("txt" . find-file))
  "Mapping from file extension to opener function."
  :type '(alist :key-type string :value-type function)
  :group 'increamemo)

(defcustom increamemo-reschedule-function #'ignore
  "Function used to calculate the next due date."
  :type 'function
  :group 'increamemo)

(defcustom increamemo-invalid-opener-policy 'keep
  "Policy used when opening an item fails."
  :type '(choice (const keep) (const archive) (const delete))
  :group 'increamemo)

(defcustom increamemo-mode-line-format-function #'identity
  "Function used to render the work session mode line."
  :type 'function
  :group 'increamemo)

(defcustom increamemo-backends
  '(increamemo-file-backend increamemo-ekg-backend)
  "Backend symbols known to increamemo."
  :type '(repeat symbol)
  :group 'increamemo)

(defun increamemo-config-db-file ()
  "Return the configured database path."
  (when increamemo-db-file
    (expand-file-name increamemo-db-file)))

(defun increamemo-config-snapshot ()
  "Return a plist snapshot of the current configuration."
  (list :db-file (increamemo-config-db-file)
        :invalid-opener-policy increamemo-invalid-opener-policy
        :mode-line-format-function increamemo-mode-line-format-function
        :backends increamemo-backends))

(defun increamemo-config-require-ready ()
  "Return a configuration snapshot or raise `user-error'."
  (unless (and (stringp increamemo-db-file)
               (> (length increamemo-db-file) 0))
    (user-error "Increamemo: `increamemo-db-file' is not configured"))
  (increamemo-config-snapshot))

(provide 'increamemo-config)
;;; increamemo-config.el ends here
