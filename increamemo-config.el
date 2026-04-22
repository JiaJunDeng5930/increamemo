;;; increamemo-config.el --- Configuration for increamemo  -*- lexical-binding: t; -*-

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

;; User-facing configuration and readiness checks.

;;; Code:

(require 'seq)

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

(defcustom increamemo-priority-schedule-rules
  '((:max-priority 10 :first-interval-days 1 :a-factor 1.10)
    (:max-priority 30 :first-interval-days 2 :a-factor 1.15)
    (:max-priority 60 :first-interval-days 4 :a-factor 1.25)
    (:max-priority 80 :first-interval-days 14 :a-factor 1.50)
    (:max-priority 100 :first-interval-days 30 :a-factor 2.00))
  "Rules used to derive the first interval and multiplier from priority.

Each rule is a plist with `:max-priority', `:first-interval-days', and
`:a-factor'.  The first rule whose `:max-priority' is greater than or equal to
the item priority applies."
  :type '(repeat
          (plist :tag "Priority schedule rule"
                 :options ((:max-priority integer)
                           (:first-interval-days integer)
                           (:a-factor number))))
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

(defun increamemo-config--valid-db-file-p (path)
  "Return non-nil when PATH names a usable database file location."
  (and (stringp path)
       (> (length path) 0)
       (let ((expanded-path (expand-file-name path)))
         (and (not (directory-name-p expanded-path))
              (not (file-directory-p expanded-path))))))

(defun increamemo-config-snapshot ()
  "Return a plist snapshot of the current configuration."
  (list :db-file (increamemo-config-db-file)
        :invalid-opener-policy increamemo-invalid-opener-policy
        :priority-schedule-rules increamemo-priority-schedule-rules
        :reschedule-function increamemo-reschedule-function
        :mode-line-format-function increamemo-mode-line-format-function
        :backends increamemo-backends))

(defun increamemo-config--valid-invalid-opener-policy-p (policy)
  "Return non-nil when POLICY is a supported invalid opener policy."
  (memq policy '(keep archive delete)))

(defun increamemo-config--valid-priority-schedule-rules-p (rules)
  "Return non-nil when RULES define a complete priority schedule."
  (let ((previous-max -1)
        (valid t))
    (and (proper-list-p rules)
         (> (length rules) 0)
         (progn
           (dolist (rule rules)
             (let ((max-priority (plist-get rule :max-priority))
                   (first-interval-days (plist-get rule :first-interval-days))
                   (a-factor (plist-get rule :a-factor)))
               (unless (and (integerp max-priority)
                            (<= 0 max-priority)
                            (<= max-priority 100)
                            (> max-priority previous-max)
                            (integerp first-interval-days)
                            (> first-interval-days 0)
                            (numberp a-factor)
                            (>= a-factor 1.0))
                 (setq valid nil))
               (setq previous-max max-priority)))
           (and valid
                (= previous-max 100))))))

(defun increamemo-config--valid-backends-p (backends)
  "Return non-nil when BACKENDS is a list of backend symbols."
  (and (proper-list-p backends)
       (seq-every-p
        (lambda (backend)
          (and backend
               (symbolp backend)))
        backends)))

(defun increamemo-config-require-ready ()
  "Return a configuration snapshot or raise `user-error'."
  (unless (increamemo-config--valid-db-file-p increamemo-db-file)
    (user-error "Increamemo: `increamemo-db-file' is not configured"))
  (unless
      (increamemo-config--valid-invalid-opener-policy-p
       increamemo-invalid-opener-policy)
    (user-error "Increamemo: invalid opener policy: %S"
                increamemo-invalid-opener-policy))
  (unless
      (increamemo-config--valid-priority-schedule-rules-p
       increamemo-priority-schedule-rules)
    (user-error "Increamemo: invalid priority schedule rules: %S"
                increamemo-priority-schedule-rules))
  (unless (functionp increamemo-reschedule-function)
    (user-error "Increamemo: invalid reschedule function: %S"
                increamemo-reschedule-function))
  (unless (functionp increamemo-mode-line-format-function)
    (user-error "Increamemo: invalid mode line format function: %S"
                increamemo-mode-line-format-function))
  (unless (increamemo-config--valid-backends-p increamemo-backends)
    (user-error "Increamemo: invalid backend list: %S"
                increamemo-backends))
  (increamemo-config-snapshot))

(defun increamemo-config-priority-schedule-for-priority (priority)
  "Return the configured schedule rule for PRIORITY."
  (or
   (seq-find
    (lambda (rule)
      (<= priority (plist-get rule :max-priority)))
    increamemo-priority-schedule-rules)
   (user-error "Increamemo: no priority schedule rule for %s" priority)))

(provide 'increamemo-config)
;;; increamemo-config.el ends here
