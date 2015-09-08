open Tk
open StdLabels
open Types

let top = openTk () ;;
Wm.title_set top "Pangrid" ;;
Wm.geometry_set top "320x120"

let make_canvas parent =
   Canvas.create
      ~width:600
      ~height:600
      ~borderwidth:2
      ~relief:`Sunken
      ~background: `White
      parent


let scale = 30

let topleft x y = x * scale, y * scale

let square_coords x y =
  let x, y = topleft x y in
  x, y, x + scale, y + scale

let letter_coords x y =
  let x, y = topleft x y in
  let s = scale/2 in
  x + s, y + s

let number_coords x y =
  let x, y = topleft x y in
  x + scale - 5, y + 5

let make_square c x y =
  let x1, y1, x2, y2 = square_coords x y in
  Canvas.create_rectangle c ~x1:x1 ~y1:y1 ~x2:x2 ~y2:y2 ~fill:`White

let make_letter c x y s =
  let x, y = letter_coords x y in
  Canvas.create_text c ~x:x ~y:y ~text:s ~font:"Arial 14"

let make_number c x y n =
  let x, y = number_coords x y in
  Canvas.create_text c ~x:x ~y:y ~text:(string_of_int n) ~font:"Arial 6" 

type xw_cell = {
  x : int;
  y : int;
  square : Tk.tagOrId;
  letter : Tk.tagOrId;
  number : Tk.tagOrId;
}

let letter_of_cell = function
  | Black -> "#"
  | Empty -> " "
  | Letter c -> c
  | Rebus (s, c) -> c

let make_xword ~canvas ~grid =
  Array.mapi grid.Xword.grid ~f:(fun x row ->
      Array.mapi row ~f: (fun y s -> begin
            let sq = make_square canvas x y
            and l = make_letter canvas x y (letter_of_cell s.cell) 
            and n = make_number canvas x y s.num 
            in { x; y; square = sq; letter = l; number = n }
          end))
            
class xw_canvas ~parent ~grid:g =
  let c = make_canvas parent in
  object(self)
  val canvas = c
  val grid = g
  val cells = make_xword ~canvas:c ~grid:g

  initializer
    for y = 0 to 14 do
      for x = 0 to 14 do
        Canvas.configure_text canvas cells.(y).(x).letter ~text:"A"
      done
    done;
    pack [canvas]
end

let grid = Xword.make 15 15
let xw = new xw_canvas ~parent:top ~grid

let _ = Printexc.print mainLoop ();;
