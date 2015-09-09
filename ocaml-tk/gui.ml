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

let make_square canvas x y =
  let x1, y1, x2, y2 = square_coords x y in
  Canvas.create_rectangle canvas ~x1:x1 ~y1:y1 ~x2:x2 ~y2:y2 ~fill:`White

let make_letter canvas x y =
  let x, y = letter_coords x y in
  Canvas.create_text canvas ~x:x ~y:y ~text:" " ~font:"Arial 14"

let make_number canvas x y =
  let x, y = number_coords x y in
  Canvas.create_text canvas ~x:x ~y:y ~text:" " ~font:"Arial 6"

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

let bg_of_cell = function
  | Black -> `Black
  | _ -> `White

let make_xword ~canvas ~grid =
  Array.mapi grid ~f:(fun x row ->
      Array.mapi row ~f: (fun y _ -> begin
            let sq = make_square canvas x y
            and l = make_letter canvas x y
            and n = make_number canvas x y
            in { x; y; square = sq; letter = l; number = n }
          end))

class xw_canvas ~parent ~xword:xw =
  let c = make_canvas parent in
  object(self)
  val canvas = c
  val grid = xw.Xword.grid
  val xword = xw
  val cells = make_xword ~canvas:c ~grid:xw.Xword.grid

  initializer
    self#update_display;
    pack [canvas]

  method update_display =
    Xword.renumber xword;
    for y = 0 to 14 do
      for x = 0 to 14 do
        self#sync_cell x y
      done
    done;

  method set_bg x y =
    Canvas.configure_rectangle canvas cells.(y).(x).square
      ~fill:(bg_of_cell grid.(y).(x).cell)

  method set_letter x y =
    Canvas.configure_text canvas cells.(y).(x).letter
      ~text:(letter_of_cell grid.(y).(x).cell)

  method set_number x y =
    let n = grid.(y).(x).num in
    let s = if (n = 0) then " " else (string_of_int n) in
    Canvas.configure_text canvas cells.(y).(x).number ~text:s

  method sync_cell x y =
    self#set_bg x y;
    self#set_number x y;
    self#set_letter x y;

end

let xw = Xword.make 15 15
let xw_widget = new xw_canvas ~parent:top ~xword:xw

let _ = Printexc.print mainLoop ();;
