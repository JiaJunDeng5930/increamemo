;;; increamemo.el --- Scheduled note review package -*- lexical-binding: t; -*-

;; Author: Jiajun Deng
;; Maintainer: Jiajun Deng
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, outlines, tools
;; URL: https://github.com/JiaJunDeng5930/increamemo

;;; Commentary:

;; Public entrypoints for the increamemo package.

;;; Code:

(require 'increamemo-backend)
(require 'increamemo-board)
(require 'increamemo-config)
(require 'increamemo-migration)
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
  (user-error "Increamemo: add-current is not implemented yet"))

;;;###autoload
(defun increamemo-work ()
  "Start an increamemo work session."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-work-start))

;;;###autoload
(defun increamemo-board ()
  "Open the increamemo board."
  (interactive)
  (increamemo-config-require-ready)
  (increamemo-board-open))

(provide 'increamemo)
;;; increamemo.el ends here
