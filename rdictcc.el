;;; rdictcc.el --- use the rdictcc.rb client from within Emacs

;; Copyright (C) 2006, 2007 by Tassilo Horn

;; Author: Tassilo Horn <tassilo@member.fsf.org>

;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 3, or (at your option) any later
;; version.

;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
;; more details.

;; You should have received a copy of the GNU General Public License along with
;; this program ; see the file COPYING.  If not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

;;; Commentary:

;; Some functions to let you use dictcc.rb from within emacs.

(defgroup rdictcc
  nil
  "A client for accessing the rdictccserver. It provides a fast
and convenient German-English (and vice versa) translation."
  :group 'hypermedia)

(defcustom rdictcc-program
  "/usr/local/bin/rdictcc.rb"
  "The path to rdictcc.rb client app."
  :group 'rdictcc
  :type 'string)

(defcustom rdictcc-show-translations-in-tooltips
  nil
  "If set to t, translations will be shown in tooltips. Tooltips
are only available in GNU Emacs' X11 interface."
  :group 'rdictcc
  :type 'boolean)

(defcustom rdictcc-show-translations-in-buffer
  t
  "If set to t, translations will be shown in a separate
*rdictcc* buffer."
  :group 'rdictcc
  :type 'boolean)

(defvar rdictcc-last-word nil
  "The last translated word (internal use only)")

(defvar rdictcc-last-translation nil
  "The last translation (internal use only)")

(defvar rdictcc-version "<2007-03-04 Sun 21:50>"
  "rdictcc.el's version")

(defun rdictcc-translate-word-to-string (word)
  "Translates the given word and returns the result as string."
  (if (equal word rdictcc-last-word)
      rdictcc-last-translation
    (let ((translation (shell-command-to-string
                        (concat rdictcc-program " " word))))
      (setq rdictcc-last-word word)
      (setq rdictcc-last-translation translation))))

(defun rdictcc-translate-word (word)
  "Asks the use for a word and translates it with
`rdictcc-program'. The result will be displayed in a window with
*rdictcc* buffer or/and in a tooltip. The variables
`rdictcc-show-translations-in-buffer' and
`rdictcc-show-translations-in-tooltips' influence this
behavior. The *rdictcc* buffer has his own major mode with useful
key bindings. Type `?' in it to get a description."
  (interactive (list (let ((inhibit-read-only t))
                       (substring-no-properties
                        (read-string "Word to translate: "
                                     (word-at-point))))))
  (let ((translation (rdictcc-translate-word-to-string word)))
    (when rdictcc-show-translations-in-buffer
      (rdictcc-pop-to-translation-buffer translation))
    (when (and rdictcc-show-translations-in-tooltips window-system)
      (tooltip-show translation))))

(defvar rdictcc-old-window-configuration nil
  "The window configuration which has to be restored when the
*rdictcc* buffer is closed. (internal use only)")

(defun rdictcc-pop-to-translation-buffer (translation)
  (setq rdictcc-old-window-configuration (current-window-configuration))
  (pop-to-buffer "*rdictcc*" nil t)
  (rdictcc-buffer-mode)
  (setq buffer-read-only nil)
  (erase-buffer)
  (insert translation)
  (setq buffer-read-only t)
  (goto-char (point-min))
  (rdictcc-next-translation))

(defun rdictcc-current-word ()
  (if (>= emacs-major-version 22)
      (current-word t t) ; emacs 22
    (current-word t)))   ; emacs 21

(defun rdictcc-translate-word-at-point ()
  "Opens a new window showing the translation of the word located
at point."
  (interactive)
  (save-excursion
    (let ((word (rdictcc-current-word)))
      (rdictcc-translate-word word))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; RdictCc Buffer Mode (major mode)

(define-derived-mode rdictcc-buffer-mode nil "rdictcc buffer"
  "The buffer used in the *rdictcc* buffers. Has some convenient
key bindings to allow fast usage, and the word whose translations
is displayed is highlighted with `font-lock-keyword-face'."
  (setq buffer-read-only t) ; *rdictcc* is read-only by default
  ;;;;;;;;;;;;;;;
  ;; Keymap Stuff
  (suppress-keymap rdictcc-buffer-mode-map)
  (define-key rdictcc-buffer-mode-map (kbd "q") 'rdictcc-close-buffer)
  (define-key rdictcc-buffer-mode-map (kbd "o") 'other-window)
  (define-key rdictcc-buffer-mode-map (kbd "RET")
    'rdictcc-replace-word-with-translation-at-point)
  (define-key rdictcc-buffer-mode-map (kbd "?") 'describe-mode)
  (define-key rdictcc-buffer-mode-map (kbd "n") 'rdictcc-next-translation)
  (define-key rdictcc-buffer-mode-map (kbd "p") 'rdictcc-previous-translation)
  (define-key rdictcc-buffer-mode-map (kbd "W d")
    'rdictcc-webtranslate-last-word-with-dictcc)
  (define-key rdictcc-buffer-mode-map (kbd "W l")
    'rdictcc-webtranslate-last-word-with-leo)
  ;;;;;;;;;;;;;;;;;;
  ;; Font Lock Stuff
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults
        ;; The translated word is highlighted in *rdictcc* buffer.
        `((,(concat "\\b" rdictcc-last-word "\\b")) t t)))

(defun rdictcc-replace-word-with-translation-at-point ()
  "Replaces the translated word with the translation at point in
*rdictcc* buffer."
  (interactive)
  (let ((chosen-translation (rdictcc-current-word)))
    (rdictcc-close-buffer)
    (search-forward-regexp "\\>")
    (backward-kill-word 1)
    (insert chosen-translation)))

(defun rdictcc-close-buffer ()
  "Closes the *rdictcc* buffer and restores the window
configuration which existed before the translation."
  (interactive)
  (set-window-configuration rdictcc-old-window-configuration))

(defun rdictcc-next-translation ()
  "Go to the next translation in *rdictcc* buffer."
  (interactive)
  (search-forward-regexp (concat "^.*" rdictcc-last-word ".*:") nil t))

(defun rdictcc-previous-translation ()
  "Go to the previous translation in *rdictcc* buffer."
  (interactive)
  (search-backward-regexp (concat "^.*" rdictcc-last-word ".*:") nil t))

(defvar rdictcc-webtranslate-symbols '("dictcc" "leo")
  "A list of symbol names (as strings) which name the translation
sites rdictcc can use as webtranslation sites. These strings are
used to complete the site symbol when interactively calling
`rdictcc-webtranslate'.")

(defun rdictcc-webtranslate-last-word-with-dictcc ()
  "Openes the browser specified by `browse-url-browser-function'
with http://www.dict.cc's translation of the last translated
word."
  (interactive)
  (rdictcc-webtranslate rdictcc-last-word 'dictcc))

(defun rdictcc-webtranslate-last-word-with-leo ()
  "Openes the browser specified by `browse-url-browser-function'
with http://dict.leo.org's translation of the last translated
word."
  (interactive)
  (rdictcc-webtranslate rdictcc-last-word 'leo))

(defun rdictcc-webtranslate (word &optional site)
  "Opens the browser defined by `browse-url-browser-function' and
translates the given word at the given site, which has to be one
symbol of

    * dictcc or (none): Translation at http://www.dict.cc

    * leo: Translation at http://dict.leo.org

If no symbol is given http://dict.cc will be queried."
  (interactive
   (list (read-string "Word to translate: ")
         (completing-read "Site symbol: " rdictcc-webtranslate-symbols)))
  (cond
   ((eq site 'leo)
    (browse-url (concat "http://dict.leo.org/?search=" word)))
   (t
    (browse-url (concat "http://www.dict.cc/?s=" word)))))

;;; end of RdictCc Buffer Mode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Tooltip mode stuff (minor mode)

(defvar rdictcc-tooltip-mode nil
  "Indicates wheather the rdictcc tooltip mode is active. Setting
this variable doesn't have any effect. Use function
`rdictcc-tooltip-mode' instead.")
(nconc minor-mode-alist '((rdictcc-tooltip-mode " RDictCc")))

(defcustom rdictcc-tooltip-delay
  2
  "How long should the mouse be over a word until the translation
will be displayed in a tooltip. Don't set it to a too low value."
  :group 'rdictcc
  :type 'number)

(defun rdictcc-translate-word-open-tooltip (event)
  "Display translations of the word under the mouse pointer in a
tooltip."
  (interactive "e")
  (let ((word (save-window-excursion
                (save-excursion
                  (mouse-set-point event)
                  (rdictcc-current-word)))))
    (when word
      (if (string= word rdictcc-last-word)
          (tooltip-show rdictcc-last-translation)
        (tooltip-show (rdictcc-translate-word-to-string word))))))

(defun rdictcc-tooltip-mode (&optional arg)
  "Display tooltips with the translations of the word under the
mouse pointer."
  (interactive "P")
  (require 'tooltip)
  (require 'gud) ;; The tooltips with events are currently part of GUD
  (let ((val (if arg
                 (> (prefix-numeric-value arg) 0)
               (not rdictcc-tooltip-mode))))
    (if val
        ;; Switch tooltip mode on
        (progn
          (make-local-variable 'rdictcc-tooltip-mode)
          (setq rdictcc-tooltip-mode val)
          (make-local-variable 'tooltip-delay)
          (setq tooltip-delay rdictcc-tooltip-delay)
          (gud-tooltip-mode 1)
          (add-hook 'tooltip-hook 'rdictcc-translate-word-open-tooltip t t)
          (make-local-variable 'track-mouse)
          (setq track-mouse val))
      ;; Switch tooltip mode off
      (kill-local-variable 'rdictcc-tooltip-mode)
      (kill-local-variable 'tooltip-delay)
      (kill-local-variable 'track-mouse)
      (remove-hook 'tooltip-hook 'rdictcc-translate-word-open-tooltip t))))

;;; end of tooltip stuff
;;;;;;;;;;;;;;;;;;;;;;;;

(provide 'rdictcc)

;;; rdictcc ends here
