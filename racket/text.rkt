#lang typed/racket

(require "xword.rkt"
         "formatter.rkt")

(: format-grid (-> Grid String))
(define (format-grid grid)
  (grid->string grid (make-opts #:empty " ."
                                #:black " #")))
(: format-clues (-> (Listof Integer) (Listof String) String))
(define (format-clues nums clues)
  (for/fold ([s ""])
            ([clue clues]
             [num nums])
    (string-append s (~a num) ". " clue "\n")))

(: text/write (-> xword String))
(define (text/write xword)
  (let* ([grid (xword-grid xword)]
         [clues (xword-clues xword)]
         [across (clues-across clues)]
         [down (clues-down clues)])
    (let-values ([(across-nums down-nums) (renumber! grid)])
      (string-append (format-grid grid) "\n"
                     "Across\n"
                     (format-clues across-nums across) "\n"
                     "Down\n"
                     (format-clues down-nums down) "\n"))))
