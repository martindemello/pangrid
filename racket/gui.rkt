#lang racket/gui

(require
  framework
  "formatter.rkt"
  "utils.rkt"
  "xword.rkt")

(application:current-app-name "Pangrid")

;;; complex numbers as (x, y)
(define pt make-rectangular)
(define pt-x real-part)
(define pt-y imag-part)

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
     [cursor (pt 1 1)]
     [scale 30]
     [pad 30]
     [height 600]
     [width 600])

    (define topleft (pt pad pad))
    (define letter-offset (pt (/ scale 4) (/ scale 4)))
    (define number-offset (pt (- scale 10) 2))

    (define/private (pos->xy p)
      (+ topleft (* scale p)))

    (define/private (xy->pos p)
      (let* ([xy (- p topleft)]
             [r (quotient (pt-x xy) scale)]
             [c (quotient (pt-y xy) scale)])
        (pt r c)))

    (define/private (draw-letter dc pos s)
      (let* ([xy (+ letter-offset (pos->xy pos))]
             [x (pt-x xy)]
             [y (pt-y xy)])
        (send* dc
          (set-font letter-font)
          (draw-text s x y))))

    (define/private (draw-number dc pos n)
      (let* ([xy (+ number-offset (pos->xy pos))]
             [x (pt-x xy)]
             [y (pt-y xy)])
        (send* dc
          (set-font number-font)
          (draw-text (~a n #:align 'right) x y))))

    (define/private (draw-square dc brush pos)
      (let* ([xy (pos->xy pos)]
             [x (pt-x xy)]
             [y (pt-y xy)])
        (send* dc
          (set-brush brush)
          (draw-rectangle x y (++ scale) (++ scale)))))

    (define wbrush (new brush% [color "white"]))
    (define bbrush (new brush% [color "black"]))
    (define cursor-brush (new brush% [color (make-color 128 255 128 0.5)]))
    (define letter-font (make-font #:size 14))
    (define number-font (make-font #:size 6))

    (define/private (cell-brush cell)
      (match cell
        ['black bbrush]
        [_      wbrush]))

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
               [pos (pt r c)]
               [current? (= pos cursor)])
          ; background
          (draw-square dc (cell-brush cell) pos)

          ; letter
          (match cell
            [(or (letter _) (rebus _ _)) (draw-letter dc pos s)]
            [_ '()])
          ; number
          (match (square-number sq)
            [0 '()]
            [n (draw-number dc pos n)])
          ; cursor
          (when current?
            (draw-square dc cursor-brush pos)))))

    (define/private (handle-click event)
      (let* ([x (send event get-x)]
             [y (send event get-y)]
             [pos (xy->pos (pt x y))])
        (set! cursor pos)
        (refresh)))

    (define/override (on-event event)
      (match (send event get-event-type)
        ['left-down (handle-click event)]
        [_ #t]))

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
