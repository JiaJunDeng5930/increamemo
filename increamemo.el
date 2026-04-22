;;; increamemo.el --- Scheduled note review package  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jiajun Deng

;; Author: Jiajun Deng <3230105930@zju.edu.cn>
;; Maintainer: Jiajun Deng <3230105930@zju.edu.cn>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, outlines, tools
;; URL: https://github.com/JiaJunDeng5930/increamemo

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

;; Increamemo provides scheduled review for note-like items using a
;; SQLite-backed queue.

;;; Code:

(require 'increamemo-backend)
(require 'increamemo-board)
(require 'increamemo-config)
(require 'increamemo-domain)
(require 'increamemo-migration)
(require 'increamemo-time)
(require 'increamemo-work)

;;;###autoload
(defun increamemo-init ()
  "Initialize the increamemo database."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-migration-initialize))

;;;###autoload
(defun increamemo-add-current ()
  "Add the current note buffer to increamemo."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-migration-require-initialized)
  (let* ((priority (read-number "Priority: "))
         (source-ref (increamemo-backend-identify-current (current-buffer)))
         (item (increamemo-domain-ensure-item
                source-ref
                priority
                nil
                (increamemo-time-now))))
    (message "Increamemo: added item #%s" (plist-get item :id))
    item))

;;;###autoload
(defun increamemo-work ()
  "Start an increamemo work session."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-migration-require-initialized)
  (increamemo-work-start))

;;;###autoload
(defun increamemo-board ()
  "Open the increamemo board."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-migration-require-initialized)
  (increamemo-board-open))

(provide 'increamemo)
;;; increamemo.el ends here
