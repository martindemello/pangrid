#lang racket/gui

(require
  framework
  srfi/25)

(application:current-app-name "Pangrid")

;;; grid

(define (make-grid cols rows)
  (build-vector cols (λ (i) (make-vector rows 'empty))))

(define (grid-get grid x y)
  (vector-ref (vector-ref grid y) x))

(define (grid-set! grid x y c)
  (vector-set! (vector-ref grid y) x c))

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

    (define/private (top-left r c)
      (list (+ pad (* r scale))
            (+ pad (* c scale))))
    
    (define wbrush (new brush% [color "white"]))
    (define bbrush (new brush% [color "black"]))
    
    (define/private (my-paint-callback self dc)
      (send* dc
        (set-brush (new brush% [style 'transparent]))
        (set-pen (new pen% [color "black"]))
        (draw-rectangle 0 0 height width))
      (for ([r rows])
        (for ([c cols])
          (match-let ([(list x y) (top-left r c)])
        (let ([brush (match (grid-get grid r c)
                      ['black bbrush]
                      [_      wbrush])])
          (send* dc
            (set-brush brush)
            (draw-rectangle x y (+ scale 1) (+ scale 1))))))))
    
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

    (grid-set! grid 0 0 'black)
    (grid-set! grid 1 0 'black)
    (grid-set! grid 2 5 'black)
    
    (define canvas
      (new xword-canvas%
           [parent container]
           [grid grid]))
    
    (define/public (show)
      (send frame show #t))
    
    (super-new)))

(define app (new application%))
(send app show)