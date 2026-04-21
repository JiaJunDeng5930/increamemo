;;; increamemo-board.el --- Board runtime for increamemo -*- lexical-binding: t; -*-

;;; Commentary:

;; Board major mode placeholder.

;;; Code:

(require 'tabulated-list)

(define-derived-mode increamemo-board-mode tabulated-list-mode "Increamemo Board"
  "Major mode for the increamemo board."
  (setq tabulated-list-format
        [("Type" 12 t)
         ("Due Date" 12 t)
         ("Priority" 10 t)
         ("State" 10 t)
         ("Opener" 20 t)
         ("Title" 24 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

(defun increamemo-board-open ()
  "Open the board buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*Increamemo Board*")))
    (with-current-buffer buffer
      (increamemo-board-mode)
      (setq tabulated-list-entries nil)
      (tabulated-list-print))
    (pop-to-buffer buffer)))

(provide 'increamemo-board)
;;; increamemo-board.el ends here
