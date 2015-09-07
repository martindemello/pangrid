#lang typed/racket

(provide (all-defined-out)
         (struct-out square-format-opts))

(require "xword.rkt")

(: cell->string (-> Cell String))
(define (cell->string cell)
  (match cell
    ['black "#"]
    ['empty "."]
    [(letter c) (string c)]
    [(rebus s c) s]))

(: cell->char (-> Cell Char))
(define (cell->char cell)
  (match cell
    ['black #\#]
    ['empty #\.]
    [(letter c) c]
    [(rebus s c) c]))

(struct square-format-opts ([black : String]
                            [empty : String]
                            [rebus : (-> Char String String)]
                            [fmt : (-> square String Integer String)]))

(: make-opts (-> [#:black String] [#:empty String]
                  [#:rebus (-> Char String String)]
                  [#:fmt (-> square String Integer String)]
                  square-format-opts))

(define (make-opts #:black [black "#"]
                   #:empty [empty " "]
                   #:rebus [reb (λ (#{c : Char} #{s : String}) (string c))]
                   #:fmt [fmt (λ (#{sq : square} #{s : String} #{n : Integer}) s)])
  (square-format-opts black empty reb fmt))
                         
                     
(: square->string (-> square square-format-opts String))
(define (square->string sq opts)
  (let ([num (square-number sq)]
        [cell (square-cell sq)]
        [black (square-format-opts-black opts)]
        [empty (square-format-opts-empty opts)]
        [reb (square-format-opts-rebus opts)]
        [fmt (square-format-opts-fmt opts)])
    (match cell
      ['black black]
      ['empty (fmt sq empty num)]
      [(letter c) (fmt sq (string c) num)]
      [(rebus s c) (fmt sq (reb c s) num)])))

(: row->string (-> (Vectorof square) square-format-opts String))
(define (row->string row opts)
  (for/fold ([#{s : String} ""])
            ([sq row])
    (string-append s (square->string sq opts))))

(: grid->string (-> Grid square-format-opts String))
(define (grid->string grid opts)
  (for/fold ([#{s : String} ""])
            ([row grid])
    (string-append s (row->string row opts) (string #\newline))))