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


;; brushes, fonts, etc.

(define (brush c s)
  (send the-brush-list find-or-create-brush c s))

(define black-pen (new pen% [color "black"]))
(define transparent-brush (brush "white" 'transparent))
(define white-brush (brush "white" 'solid))
(define black-brush (brush "black" 'solid))
(define cursor-brush (brush (make-color 128 255 128 0.5) 'solid))
(define letter-font (make-font #:size 14))
(define number-font (make-font #:size 6))

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
     [dir 'across]
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

    (define/private (cell-brush cell)
      (match cell
        ['black black-brush]
        [_      white-brush]))

    (define/private (my-paint-callback self dc)
      (send* dc
        (set-brush transparent-brush)
        (set-pen black-pen)
        (draw-rectangle 0 0 height width))

      (for* ([r rows]
             [c cols])
        (let* ([sq (grid-get grid r c)]
               [cell (square-cell sq)]
               [pos (pt r c)]
               [current? (= pos cursor)])
          ; background
          (draw-square dc (cell-brush cell) pos)
          ; letter
          (match cell
            [(or (? letter?) (? rebus?))
             (draw-letter dc pos (string (cell->char cell)))]
            [_ (void)])
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

    (define/private (get-grid-cell pos)
      (square-cell (grid-get grid (pt-x pos) (pt-y pos))))

    (define/private (toggle-black! x y cell)
      (match cell
        ['black (grid-set-cell! grid x y 'empty)]
        ['empty (grid-set-cell! grid x y 'black)]
        [_ (void)])
      (renumber! grid)
      (refresh))

    (define/private (toggle-dir!)
      (set! dir (if (eq? dir 'across) 'down 'across)))

    (define/private (delta dir)
      (match dir
        ['across (pt 1 0)]
        ['down (pt 0 1)]
        ['left (pt -1 0)]
        ['right (pt 1 0)]
        ['up (pt 0 -1)]
        ['down (pt 0 1)]))

    (define/private (wrap-pos pos)
      (pt (modulo (pt-x pos) cols)
          (modulo (pt-y pos) rows)))

    (define/private (clip-pos pos)
      (pt (clip (pt-x pos) 0 (-- cols))
          (clip (pt-y pos) 0 (-- rows))))

    (define/private (move-cursor-wrap! delta)
      (set! cursor (wrap-pos (+ cursor delta))))

    (define/private (move-cursor-clip! delta)
      (set! cursor (clip-pos (+ cursor delta))))

    (define/private (delete-cell! x y cell)
      (unless (equal? 'black cell)
        (grid-set-cell! grid x y 'empty))
      (refresh))

    (define/private (backspace! x y cell)
      (delete-cell! x y cell)
      (move-cursor-clip! (- (delta dir)))
      (refresh))

    (define/private (move-cursor! d)
      (move-cursor-wrap! (delta d))
      (refresh))

    (define/private (set-cell! x y cell c)
      (unless (equal? 'black cell)
        (grid-set-cell! grid x y (letter c)))
      (move-cursor-clip! (delta dir))
      (refresh))

    (define/override (on-event event)
      (match (send event get-event-type)
        ['left-down (handle-click event)]
        [_ #t]))

    (define/override (on-char event)
      (let ([keycode (send event get-key-code)]
            [x (pt-x cursor)]
            [y (pt-y cursor)]
            [cell (get-grid-cell cursor)])
        (match keycode
          [(or 'left 'right 'up 'down) (move-cursor! keycode)]
          [#\space (toggle-black! x y cell)]
          [#\rubout (delete-cell! x y cell)]
          [#\backspace (backspace! x y cell)]
          [#\tab (toggle-dir!)]
          ['escape (dump-memory-stats)]
          [(? char? c) (set-cell! x y cell c)]
          [_ (void)])))

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
