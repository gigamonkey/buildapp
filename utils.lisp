;;;;
;;;; Copyright (c) 2010 Zachary Beane, All Rights Reserved
;;;;
;;;; Redistribution and use in source and binary forms, with or without
;;;; modification, are permitted provided that the following conditions
;;;; are met:
;;;;
;;;;   * Redistributions of source code must retain the above copyright
;;;;     notice, this list of conditions and the following disclaimer.
;;;;
;;;;   * Redistributions in binary form must reproduce the above
;;;;     copyright notice, this list of conditions and the following
;;;;     disclaimer in the documentation and/or other materials
;;;;     provided with the distribution.
;;;;
;;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR 'AS IS' AND ANY EXPRESSED
;;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;;

;;;; utils.lisp

(in-package #:buildapp)

(defparameter *alphabet*
  (concatenate 'string
               "abcdefghijklmnopqrstuvwxyz"
               "0123456789"
               "ABCDEFGHIJKLMNOPQRSTUVWXYZ"))

(defun random-string (length)
  "Return a random string with LENGTH characters."
  (let ((string (make-string length)))
    (map-into string (lambda (char)
                       (declare (ignore char))
                       (aref *alphabet* (random (length *alphabet*))))
              string)))

(defun call-with-temporary-open-file (template fun &rest open-args
                                      &key element-type external-format)
  "Call FUN with two arguments: an open output stream and a file
name. When it returns, the file is deleted. TEMPLATE should be a
pathname that can be used as a basis for the temporary file's
location."
  (declare (ignorable element-type external-format))
  (flet ((new-name ()
           (make-pathname :name (concatenate 'string
                                             (pathname-name template)
                                             "-"
                                             (random-string 8))
                          :defaults template)))
    (let (try stream)
      (tagbody
       :retry
         (setf try (new-name))
         (unwind-protect
              (progn
                (setf stream (apply #'open try
                                    :if-exists nil
                                    :direction :output
                                    open-args))
                (unless stream
                  (go :retry))
                (funcall fun stream try))
           (when stream
             (close stream)
             (ignore-errors (delete-file try))))))))

(defmacro with-tempfile ((stream (template file) &rest open-args) &body body)
  `(call-with-temporary-open-file ,template
                                  (lambda (,stream ,file)
                                    ,@body)
                                  ,@open-args))

(defclass pseudosymbol ()
  ((package-string
    :initarg :package-string
    :accessor package-string)
   (symbol-string
    :initarg :symbol-string
    :accessor symbol-string)))

(defmethod print-object ((pseudosymbol pseudosymbol) stream)
  (format stream "~A::~A"
          (package-string pseudosymbol)
          (symbol-string pseudosymbol)))

(defun make-pseudosymbol (string)
  (let* ((package-start 0)
         (package-end (position #\: string))
         (symbol-start (and package-end (position #\: string
                                                  :start package-end
                                                  :test-not #'eql)))
         (package (if package-end
                      (subseq string package-start package-end)
                      "cl-user"))
         (symbol (if symbol-start
                     (subseq string symbol-start)
                     string)))
    (make-instance 'pseudosymbol
                   :package-string package
                   :symbol-string symbol)))


(defun directorize (namestring)
  (concatenate 'string (string-right-trim "/" namestring) "/"))

(defun all-asdf-directories (root)
  "Return a list of all ASDF files in the directory tree at ROOT."
  (remove-duplicates
   (mapcar #'directory-namestring
           (directory (merge-pathnames "**/*.asd"
                                       (pathname (directorize root)))))
   :test #'string=))

(defun copy-file (input output &key (if-exists :supersede))
  (with-open-file (input-stream input)
    (with-open-file (output-stream output :direction :output
                                   :if-exists if-exists)
      (loop for char = (read-char input-stream nil)
            while char do (write-char char output-stream)))))