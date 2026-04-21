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

(declare-function increamemo-default-reschedule "increamemo-policy" ())

(defcustom increamemo-reschedule-function #'increamemo-default-reschedule
  "Function used to calculate the next due date."
  :type 'function
  :group 'increamemo)

(defcustom increamemo-invalid-opener-policy 'keep
  "Policy used when opening an item fails."
  :type '(choice (const keep) (const archive) (const delete))
  :group 'increamemo)

(defun increamemo-default-mode-line-format (handled remaining)
  "Render HANDLED and REMAINING counts for the mode line."
  (format "IM[%d/%d]" handled remaining))

(defcustom increamemo-mode-line-format-function
  #'increamemo-default-mode-line-format
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

(defun increamemo-config--valid-invalid-opener-policy-p (policy)
  "Return non-nil when POLICY is a supported invalid opener policy."
  (memq policy '(keep archive delete)))

(defun increamemo-config-require-ready ()
  "Return a configuration snapshot or raise `user-error'."
  (unless (and (stringp increamemo-db-file)
               (> (length increamemo-db-file) 0))
    (user-error "Increamemo: `increamemo-db-file' is not configured"))
  (unless
      (increamemo-config--valid-invalid-opener-policy-p
       increamemo-invalid-opener-policy)
    (user-error "Increamemo: invalid invalid opener policy: %S"
                increamemo-invalid-opener-policy))
  (unless (functionp increamemo-mode-line-format-function)
    (user-error "Increamemo: invalid mode line format function: %S"
                increamemo-mode-line-format-function))
  (increamemo-config-snapshot))

(provide 'increamemo-config)
;;; increamemo-config.el ends here
