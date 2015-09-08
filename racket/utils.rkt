#lang typed/racket

(provide (all-defined-out))

(: ++ (-> Integer Integer))
(define (++ x) (+ x 1))

(: -- (-> Integer Integer))
(define (-- x) (- x 1))

(: clip (-> Integer Integer Integer Integer))
(define (clip n min max)
  (cond [(< n min) min]
        [(> n max) max]
        [else n]))
