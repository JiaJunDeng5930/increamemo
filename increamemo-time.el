;;; increamemo-time.el --- Time helpers for increamemo  -*- lexical-binding: t; -*-

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

;; Helpers for current date and timestamp formatting.

;;; Code:

(defun increamemo-time-today (&optional time-value)
  "Return TIME-VALUE as an ISO date, or today's date when omitted."
  (format-time-string "%F" time-value))

(defun increamemo-time-now (&optional time-value)
  "Return TIME-VALUE as an ISO 8601 timestamp, or the current time when omitted."
  (format-time-string "%FT%T%:z" time-value))

(provide 'increamemo-time)
;;; increamemo-time.el ends here
