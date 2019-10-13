;;; parse-it-lex.el --- Basic lexical analysis.  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Shen, Jen-Chieh <jcs090218@gmail.com>

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Basic lexical analysis
;;

;;; Code:

(require 'cl-lib)
(require 's)


(defvar parse-it-lex--token-type
  '(("URL" . "http[s]*://")
    ("NUMBER" . "\\`[0-9]+\\'")
    ("UNKNOWN" . ""))
  "List of token identifier.")

(defconst parse-it-lex--magic-comment-beg "COMMENT_BEG"
  "Magic string represent beginning of the comment.")

(defconst parse-it-lex--magic-comment-end "COMMENT_END"
  "Magic string represent ending of the comment.")

(defconst parse-it-lex--magic-comment "COMMENT"
  "Magic string represent single line comment.")

(defconst parse-it-lex--magic-newline "NEWLN"
  "Magic string represent newline.")

(defvar parse-it-lex--ignore-newline t
  "Ignore newline when tokenizing.")


(defun parse-it-lex--get-string-from-file (path)
  "Return PATH file content."
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun parse-it-lex--get-string-from-buffer (buf-name)
  "Return BUF-NAME file content."
  (with-current-buffer buf-name
    (buffer-string)))

(defun parse-it-lex--split-to-token-list (src-code)
  "Split SRC-CODE to list of token readable list."
  (let ((ana-src src-code) (token-regex ""))
    (setq ana-src (s-replace-regexp "[\n]" "\n " ana-src))
    (setq ana-src (s-replace-regexp "[\t]" " " ana-src))
    (dolist (token-type parse-it-lex--token-type)
      (setq token-regex (cdr token-type))
      (unless (string-empty-p token-regex)
        (setq ana-src
              (s-replace-regexp
               token-regex
               (lambda (match-str) (concat " " match-str " "))
               ana-src))))
    (split-string ana-src " " t nil)))

(defun parse-it-lex--find-token-type (sec)
  "Find out section of code's (SEC) token type."
  (let ((tk-tp "") (token-type "") (token-regex "") (tk-index 0) (tk-break nil))
    (while (and (< tk-index (length parse-it-lex--token-type))
                (not tk-break))
      (setq tk-tp (nth tk-index parse-it-lex--token-type))
      (setq token-regex (cdr tk-tp))
      (when (string-match-p token-regex sec)
        (setq token-type (car tk-tp))
        (setq tk-break t))
      (setq tk-index (1+ tk-index)))
    token-type))

(defun parse-it-lex--add-to-list (lst elm)
  "Append ELM to LST."
  (append lst (list elm)))

(defun parse-it-lex--form-node (val type ln pos)
  "Form a node with TYPE, VAL, LN and POS."
  (list :value val :type type :lineno ln :pos pos))

(defun parse-it-lex-tokenize-it (path)
  "Tokenize the PATH and return list of tokens."
  (let* ((src-code (if path (parse-it-lex--get-string-from-file path)
                     (parse-it-lex--get-string-from-buffer (current-buffer))))
         (src-sec (parse-it-lex--split-to-token-list src-code))
         (res-lst '())
         (mul-comment nil) (in-comment nil) (newline-there nil)
         (src-ln (split-string src-code "\n"))
         (cur-src-ln (nth 0 src-ln))
         (matched-pos 0)
         (ln 0) (pos 0) (token-type ""))
    (dolist (sec src-sec)
      (if (string-match-p "[\n]" sec)
          (progn
            (setq pos (+ pos (length sec)))
            (setq sec (nth 0 (split-string sec "\n")))
            ;; NOTE: Do something after seeing newline.
            (progn
              (setq ln (1+ ln))
              (setq cur-src-ln (nth ln src-ln))
              (setq matched-pos 0)
              (setq newline-there t)))
        (when newline-there (setq pos (1+ pos)))  ; Rotate add 1.
        (setq newline-there nil)
        (setq pos (- pos matched-pos))
        (setq matched-pos (string-match-p (regexp-quote sec) cur-src-ln matched-pos))
        (when matched-pos
          (setq pos (+ pos matched-pos))))
      (when (or (not (string-empty-p sec))
                newline-there)
        (setq token-type (parse-it-lex--find-token-type sec))
        (cond
         ((string= token-type parse-it-lex--magic-comment-beg) (setq mul-comment t))
         ((string= token-type parse-it-lex--magic-comment-end) (setq mul-comment nil))
         ((string= token-type parse-it-lex--magic-comment) (setq in-comment t))
         ((and in-comment newline-there (not mul-comment)) (setq in-comment nil))
         (t
          (when (and (not in-comment) (not mul-comment))
            (unless (string-empty-p sec)
              (setq res-lst
                    (parse-it-lex--add-to-list
                     res-lst
                     (parse-it-lex--form-node sec token-type (1+ ln) pos))))
            (when (and newline-there (not parse-it-lex--ignore-newline))
              (setq res-lst
                    (parse-it-lex--add-to-list
                     res-lst
                     (parse-it-lex--form-node "\n" parse-it-lex--magic-newline ln pos)))))))))
    res-lst))


(provide 'parse-it-lex)
;;; parse-it-lex.el ends here
