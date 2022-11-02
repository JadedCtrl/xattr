;;
;; Copyright 2022, Jaidyn Levesque <jadedctrl@posteo.at>
;;
;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.
;;

(module xattr
  (get-xattr set-xattr remove-xattr list-xattr split-list)

(import (chicken base) (chicken memory) srfi-1 scheme (chicken foreign) srfi-12)

(foreign-declare "#include \"xattr_ext.c\"")


;; The direct foreign binding for `get_xattr`
(define get-xattr-foreign
  (foreign-lambda c-string* "get_xattr" c-string c-string (c-pointer int)))


;; Wrapper around get-xattr-foreign, which throws exceptions and such.
(define (get-xattr path attr)
  (let-location ([error-code int])
    (let ([attr-value (get-xattr-foreign path attr (location error-code))]
		  [exception (or (getxattr-exception error-code)
						 (stat-exception error-code))])
	  (if exception
		  (signal exception)
		  attr-value))))


;; The direct foreign binding for `list_xattr`
(define list-xattr-foreign
  (foreign-lambda (c-pointer char) "list_xattr" c-string (c-pointer ssize_t) (c-pointer int)))


;; Wrapper around list-xattr-foreign, which throws exceptions and such.
(define (list-xattr path)
  (let-location ([error-code int]
				 [length ssize_t])
    (let ([list-pointer (list-xattr-foreign path (location length) (location error-code))]
		  [exception (or (getxattr-exception error-code)
						 (stat-exception error-code))])
	  (if exception
		  (signal exception)
		  ;; listxattr offers a const char* \0-delimited list of strings
		  (pointer->delimited-string-list list-pointer length 0)))))


;; The direct foreign binding for `set_xattr`
(define set-xattr-foreign
  (foreign-lambda int "set_xattr" c-string c-string c-string (c-pointer int)))


;; Wrapper around set-xattr-foreign, throwing exceptions and all that jazz
(define (set-xattr path attr value)
  (let-location ([error-code int])
    (let ([return-code (set-xattr-foreign path attr value (location error-code))]
		  [exception (or (setxattr-exception error-code)
						 (getxattr-exception error-code)
						 (stat-exception error-code))])
	  (if exception
		  (signal exception)
		  value))))


;; The direct foreign binding for `remove_xattr`
(define remove-xattr-foreign
  (foreign-lambda int "remove_xattr" c-string c-string))


;; Wrapper around remove-xattr-foreign, blah blah
(define (remove-xattr path attr)
  (let* ([error-code (remove-xattr-foreign path attr)]
		 [exception (or (getxattr-exception error-code)
						(stat-exception error-code))])
	(if exception
		(signal exception)
		attr)))


;; TODO: These exception functions should be constructed with a macro and a simple
;; list, like `((c-constant symbol error-message) ("E2BIG" 'e2big "The attribute value was too big."))
;; Unfortunately, it looks like chicken's macros work a good bit differently from CLs?
;; orr I'm losing my mind


;; Return the exception associated with an error-code as per getxattr(2), if it exists
(define (getxattr-exception error-code)
  (cond
   [(eq? error-code (foreign-value "E2BIG" int))
	(build-exception 'e2big "The attribute value was too big.")]
   [(eq? error-code (foreign-value "ENOTSUP" int))
	(build-exception 'enotsup "Extended attributes are disabled or unavailable on this filesystem.")]
   [(eq? error-code (foreign-value "ERANGE" int))
	(build-exception 'erange "The xattr module's buffer was too small for the attribute value. Whoops <w<\"")]
   [#t
	#f]))


;; Return the exception associated with a setxattr(2) error-code, if it exists.
(define (setxattr-exception error-code)
  (cond
   [(eq? error-code (foreign-value "EDQUOT" int))
	(build-exception 'edquot "Setting this attribute would violate disk quota.")]
   [(eq? error-code (foreign-value "ENOSPC" int))
	(build-exception 'enospc "There is insufficient space to store the extended attribute.")]
   [(eq? error-code (foreign-value "EPERM" int))
	(build-exception 'eperm "The file is immutable or append-only.")]
   [(eq? error-code (foreign-value "ERANGE" int))
	(build-exception 'erange "Either the attribute name or value exceeds the filesystem's limit.")]
   [#t
	#f]))


;; Return the exception associated with an error-code as per stat(2), if applicable
(define (stat-exception error-code)
  (cond
   [(eq? error-code (foreign-value "EACCES" int))
	(build-exception 'file "Search permission denied for a parent directory.")]
   [(eq? error-code (foreign-value "EBADF" int))
	(build-exception 'file "The file-descriptor is bad. Wait, wha…?")]
   [(eq? error-code (foreign-value "EFAULT" int))
	(build-exception 'file "The address is bad. OK.")]
   [(eq? error-code (foreign-value "EINVAL" int))
	(build-exception 'file "Invalid fstatat flag.")]
   [(eq? error-code (foreign-value "ELOOP" int))
	(build-exception 'file "Too many symbolic links in recursion.")]
   [(eq? error-code (foreign-value "ENAMETOOLONG" int))
	(build-exception 'file "The given pathname is too long.")]
   [(eq? error-code (foreign-value "ENOENT" int))
	(build-exception 'file "This file doesn't exist, or there is a dangling symlink.")]
   [(eq? error-code (foreign-value "ENOMEM" int))
	(build-exception 'file "Out of memory.")]
   [(eq? error-code (foreign-value "ENOTDIR" int))
	(build-exception 'file "Component of path isn't a proper directory.")]
   [(eq? error-code (foreign-value "EOVERFLOW" int))
	(build-exception 'file "An overflow has occured.")]
   [#t
	#f]))


;; Creates a generic exception with given symbol and message
(define (build-exception symbol message)
  (signal (make-property-condition 'exn 'location symbol 'message message)))


;; Some C functions offer up a string-list that isn't a two-dimensional array, but a
;; one-dimensional array with given length and strings separated by a given delimeter.
;; This takes that sort of pointer and gives you a nice list of strings.
(define (pointer->delimited-string-list pointer length delimiter)
  (let ([is-zero (lambda (num) (eq? num 0))]
		[map-to-char (lambda (a) (map integer->char a))])
	(map list->string
		 (map map-to-char
			  (split-list is-zero
						  (drop-right
						   (pointer->integers pointer length) 1))))))


;; Takes a pointer and returns a list of bytes of a given length
(define (pointer->integers pointer length)
  (let ([byte (pointer-s8-ref pointer)])
	(if (eq? length 0)
		byte
		(append (list byte)
				(pointer->integers (pointer+ pointer 1) (- length 1))))))


;; Split a list into sublists, with items passing `test` being the delimiters
(define (split-list test list)
  (let ([before (take-while (compose not test) list)]
		[after (drop-while (compose not test) list)])
	(cond
	 [(or (null-list? after) (null-list? (cdr after)))
	  `(,before)]
	 [(null-list? before)
	  (split-list test (cdr after))]
	 [#t
	  (append `(,before) (split-list test (cdr after)))])))

)
