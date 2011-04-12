;;; scrobble.el -- interfacing with last.fm

;; Copyright (C) 2011 Lars Magne Ingebrigtsen

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;; Keywords: home automation

;; This file is not part of GNU Emacs.

;; scrobble.el is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; scrobble.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Provide a convenient keypad based interface for displaying time,
;; and waking myself up in the morning.

;;; Code:

(require 'cl)
(require 'mm-url)

(defvar scrobble-user ""
  "last.fm user name."

(defvar scrobble-password ""
  "Password to use.")

;; Internal variables.

(defvar scrobble-challenge "")
(defvar scrobble-url "")
(defvar scrobble-last-file nil)
(defvar scrobble-queue nil)

(defun scrobble-login ()
  (interactive)
  (with-temp-buffer
    (call-process
     "curl" nil (current-buffer) nil
     "-s"
     (format "http://post.audioscrobbler.com/?hs=true&p=1.1&c=tst&v=10&u=%s"
	     scrobble-user))
    (goto-char (point-min))
    (when (looking-at "UPTODATE")
      (forward-line 1)
      (setq scrobble-challenge
	    (buffer-substring (point) (point-at-eol)))
      (message "Logged in to Last.fm with challenge %s"
	       scrobble-challenge)
      (forward-line 1)
      (setq scrobble-url
	    (buffer-substring (point) (point-at-eol))))))

(defun scrobble-encode (string)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file "/tmp/scrobble.string"
      (insert string)))
  (with-temp-buffer
    (insert-file-contents "/tmp/scrobble.string")
    (mm-url-form-encode-xwfu (buffer-string))))

(defun scrobble (artist album song &optional track-length cddb-id)
  (let ((spec (list artist album song)))
    (when (and (not (assoc spec scrobble-queue))
	       (not (equal spec scrobbled-last)))
      (push (append spec (list (current-time) track-length cddb-id))
	    scrobble-queue)
      (scrobble-queue))))

(defun scrobble-queue ()
  (dolist (elem (reverse scrobble-queue))
    (let* ((spec (car elem))
	   (response (scrobble-2 spec)))
      (when (zerop (length response))
	(message "No scrobble response")
	(return nil))
      (when (string-match "OK" response)
	(setq scrobble-queue
	      (delete (assoc spec scrobble-queue)
		      scrobble-queue))))))
  
(defun scrobble-2 (spec)
  (let ((response (scrobble-1 spec)))
    (when (string-match "BADAUTH" response)
      (scrobble-login)
      (setq response (scrobble-1 spec)))
    response))

(defun scrobble-1 (spec)
  (let ((coding-system-for-write 'binary))
    (destructuring-bind (artist album song time track-length cddb-id) spec
      (with-temp-file "/tmp/scrobble"
	(insert
	 (format "u=%s&s=%s&a[0]=%s&t[0]=%s&b[0]=%s&m[0]=%s&l[0]=%s&i[0]=%s"
		 scrobble-user
		 (md5 (concat (md5 scrobble-password)
			      scrobble-challenge))
		 (jukebox-scrobble-encode artist)
		 (jukebox-scrobble-encode song)
		 (jukebox-scrobble-encode album)
		 cddb-id track-length
		 (jukebox-scrobble-encode
		  (format-time-string
		   "%Y-%m-%d %H:%M:%S"
		   (time-subtract time
				  (list 0 (car (current-time-zone)))))))))))
  (scrobble-ping))

(defun scrobble-ping ()
  (with-temp-buffer
    (call-process "curl" nil (current-buffer) nil
		  "-d" "@/tmp/scrobble" "-s"
		  "-m" "1"
		  scrobble-url)
    (replace-regexp-in-string "\n" " " (buffer-string))))

(provide 'scrobble)

;;; scrobble.el ends here
