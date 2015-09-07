#lang racket/gui

(require
  framework
  "formatter.rkt"
  "utils.rkt"
  "xword.rkt")

(application:current-app-name "Pangrid")

;;; gui components

(define xword-canvas%
  (class canvas%
    (inherit
      get-width
      get-height
      refresh)

    (init-field
     parent
     grid
     [rows 15]
     [cols 15]
     [scale 30]
     [pad 30]
     [height 600]
     [width 600])

    (define/private (top r)
      (+ pad (* r scale)))

    (define/private (left c)
      (+ pad (* c scale)))

    (define/private (draw-letter dc r c s)
      (let ([offset (/ scale 4)]
            [x (left c)]
            [y (top r)])
        (send* dc
          (set-font letter-font)
          (draw-text s (+ x offset) (+ y offset)))))

    (define/private (draw-number dc r c n)
      (let ([x (left c)]
            [y (top r)])
        (send* dc
          (set-font number-font)
          (draw-text (~a n #:align 'right) (+ x (- scale 10)) (+ y 2)))))

    (define wbrush (new brush% [color "white"]))
    (define bbrush (new brush% [color "black"]))
    (define letter-font (make-font #:size 14))
    (define number-font (make-font #:size 6))

    (define/private (my-paint-callback self dc)
      (send* dc
        (set-brush (new brush% [style 'transparent]))
        (set-pen (new pen% [color "black"]))
        (draw-rectangle 0 0 height width))
      (for* ([r rows]
             [c cols])
          (let* ([sq (grid-get grid r c)]
                 [cell (square-cell sq)]
                 [s (string (cell->char cell))]
                 [x (left c)]
                 [y (top r)]
                 [offset (/ scale 4)])
            ; background
            (let ([brush (match cell
                           ['black bbrush]
                           [_      wbrush])])
              (send* dc
                (set-brush brush)
                (draw-rectangle x y (++ scale) (++ scale))))
            ; letter
            (match cell
              [(or (letter _) (rebus _ _)) (draw-letter dc r c s)]
              [_ '()])
            ; number
            (match (square-number sq)
              [0 '()]
              [n (draw-number dc r c n)])

          )))

    (super-new
     [parent parent]
     [paint-callback (λ (c dc) (my-paint-callback c dc))])

    (send this focus)))

(define application%
  (class object%

    (define frame
      (new frame:standard-menus% [label "Pangrid"]))

    (define container (send frame get-area-container))

    (define grid (make-grid 15 15))

    (grid-set-cell! grid 0 0 'black)
    (grid-set-cell! grid 1 0 'black)
    (grid-set-cell! grid 2 5 'black)
    (grid-set-cell! grid 3 5 (letter #\E))
    (grid-set-cell! grid 7 8 (rebus "heart" #\H))
    (renumber! grid)

    (define canvas
      (new xword-canvas%
           [parent container]
           [grid grid]))

    (define/public (show)
      (send frame show #t))

    (super-new)))

(define app (new application%))
(send app show)
