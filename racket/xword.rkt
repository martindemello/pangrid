#lang typed/racket

;;; utils
(: ++ (-> Integer Integer))
(define (++ x) (+ x 1))

(: -- (-> Integer Integer))
(define (-- x) (- x 1))

;;; cell
(define-type Cell (U 'black 'empty letter rebus))
(struct letter ([c : Char]))
(struct rebus ([s : String] [c : Char]))

;;; square
(struct square ([cell : Cell]
                [number : Integer])
  #:mutable)

(: square-black? (-> square Boolean))
(define (square-black? sq)
  (match (square-cell sq)
    ['black true]
    [_ false]))

(: square-rebus? (-> square Boolean))
(define (square-rebus? sq)
    (match (square-cell sq)
      [(rebus _ _) true]
      [_ false]))


(: square->string (-> square String))
(define (square->string sq)
  (match (square-cell sq)
    ['black "#"]
    ['empty: "."]
    [(letter c) (string c)]
    [(rebus s c) s]))

;;; grid
(define-type Grid (Vectorof (Vectorof square)))
(define-type GridQuery (-> Grid Integer Integer Boolean))

(: make-grid (-> Integer Integer Grid))
(define (make-grid cols rows)
  (build-vector cols (λ (i) (make-vector rows (square 'empty 0)))))

(: grid-get (-> Grid Integer Integer square))
(define (grid-get grid x y)
  (vector-ref (vector-ref grid y) x))

(: grid-set! (-> Grid Integer Integer square Void))
(define (grid-set! grid x y c)
  (vector-set! (vector-ref grid y) x c))

(: grid-set-number! (-> Grid Integer Integer Integer Void))
(define (grid-set-number! grid x y n)
  (let ([sq (grid-get grid x y)])
    (set-square-number! sq n)))

(: grid-set-cell! (-> Grid Integer Integer Cell Void))
(define (grid-set-cell! grid x y c)
  (let ([sq (grid-get grid x y)])
    (set-square-cell! sq c)))

(: grid-max-row (-> Grid Integer))
(define (grid-max-row grid)
  (-- (vector-length grid)))

(: grid-max-col (-> Grid Integer))
(define (grid-max-col grid)
  (-- (vector-length (vector-ref grid 0))))

(: black? GridQuery)
(define (black? grid x y)
  (square-black? (grid-get grid x y)))

(: white? GridQuery)
(define (white? grid x y)
  (not (black? grid x y)))

(: boundary? GridQuery)
(define (boundary? grid x y)
  (or (< x 0) (< y 0)
      (> x (grid-max-col grid)) (> y (grid-max-row grid))
      (black? grid x y)))

(: start-across? GridQuery)
(define (start-across? grid x y)
  (and (white? grid x y)
       (boundary? grid (-- x) y)))

(: start-down? GridQuery)
(define (start-down? grid x y)
  (and (white? grid x y)
       (boundary? grid x (-- y))))

(: renumber! (-> Grid (Values (Listof Integer) (Listof Integer))))
(define (renumber! grid)
  (let-values
      ([(num across down)
        (for*/fold ([#{n : Integer} 1]
                    [#{across : (Listof Integer)} '()]
                    [#{down : (Listof Integer)} '()])
                   ([x (grid-max-row grid)]
                    [y (grid-max-col grid)])
          (let* ([across* (cons n across)]
                 [down* (cons n down)]
                 [n* (++ n)]
                 [across? (start-across? grid x y)]
                 [down? (start-down? grid x y)])
            (grid-set-number! grid x y
                              (if (or across? down?) n* 0))
            (match (list across? down?)
              [(list true true) (values n* across* down*)]
              [(list true false) (values n* across* down)]
              [(list false true) (values n* across down*)]
              [(list false false) (values n across down)])))])
    (values across down)))

;;;; clues
(struct clues ([across : (Listof String)]
               [down : (Listof String)]))

; xword


