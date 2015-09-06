#lang typed/racket

;;; cell
(define-type Cell (U 'black 'empty letter rebus))
(struct letter ([c : Char]))
(struct rebus ([s : String] [c : Char]))

;;; square
(struct square ([contents : Cell]
                [number : Integer]))

(: square-black? (-> square Boolean))
(define (square-black? sq)
  (match (square-contents sq)
    ['black true]
    [_ false]))

(: square-rebus? (-> square Boolean))
(define (square-rebus? sq)
    (match (square-contents sq)
      [(rebus _ _) true]
      [_ false]))


(: square->string (-> square String))
(define (square->string sq)
  (match (square-contents sq)
    ['black "#"]
    ['empty: "."]
    [(letter c) (string c)]
    [(rebus s c) s]))
    
;;; clues
(struct clues ([across : (Listof String)]
               [down : (Listof String)]))

;;; grid
(define-type Grid (Vectorof (Vectorof square)))

(: make-grid (-> Integer Integer Grid))
(define (make-grid cols rows)
  (build-vector cols (λ (i) (make-vector rows (square 'empty 0)))))

(: grid-get (-> Grid Integer Integer square))
(define (grid-get grid x y)
  (vector-ref (vector-ref grid y) x))

(: grid-set! (-> Grid Integer Integer square Void))
(define (grid-set! grid x y c)
  (vector-set! (vector-ref grid y) x c))

;; xword

