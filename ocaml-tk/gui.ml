open Tk
open StdLabels
open Types
open Cursor

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

(* Set up grid on canvas *)
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
  square : Tk.tagOrId;
  letter : Tk.tagOrId;
  number : Tk.tagOrId;
}


let make_xword ~canvas ~grid =
  Array.mapi grid ~f:(fun y row ->
      Array.mapi row ~f: (fun x _ -> begin
            let sq = make_square canvas x y
            and l = make_letter canvas x y
            and n = make_number canvas x y
            in { square = sq; letter = l; number = n }
          end))

let printxy x y = print_endline ((string_of_int x) ^ ", " ^ (string_of_int y))

let letter_of_cell = function
  | Black -> ""
  | Empty -> ""
  | Letter c -> c
  | Rebus (s, c) -> c

let bg_of_cell cell is_cursor =
 match cell, is_cursor with
  | Black, false -> `Black
  | Black, true -> `Color "dark green"
  | _, false -> `White
  | _, true -> `Color "pale green"

class xw_canvas ~parent ~xword:xw =
  let c = make_canvas parent in
  object(self)
  val canvas = c
  val xword = xw
  val rows = xw.Xword.rows
  val cols = xw.Xword.cols
  val cells = make_xword ~canvas:c ~grid:xw.Xword.grid
  val mutable cursor = Cursor.make xw.Xword.rows xw.Xword.cols

  initializer
    self#update_display;
    pack [canvas]

  method make_bindings =
    (* per-square mouse bindings *)
    for y = 0 to rows - 1 do
      for x = 0 to cols - 1 do begin
        let bind_obj b =
          Canvas.bind canvas b ~events:[`ButtonPress]
            ~action:(fun _ -> self#set_cursor {cursor with x; y})
        in
        let c = cells.(y).(x) in
        (* we need to have all three components register clicks *)
        List.iter ~f:bind_obj [c.square; c.letter; c.number]
      end done
    done;
    (* keyboard bindings *)
    bind canvas ~events:[`KeyPress] ~fields:[`Char; `KeySymString]
      ~action:(fun ev -> self#handle_keypress ev);
    Focus.set canvas

  method update_display =
    ignore (Xword.renumber xword);
    self#make_bindings;
    for y = 0 to rows - 1 do
      for x = 0 to cols - 1 do
        self#sync_cell x y
      done
    done;

  method set_cursor new_cursor =
    let ox, oy = cursor.x, cursor.y in
    cursor <- new_cursor;
    self#sync_bg cursor.x cursor.y;
    self#sync_bg ox oy

  method move_cursor ?wrap:(wrap=true) (dir : direction) =
    let new_cursor = Cursor.move cursor ~wrap:wrap dir in
    self#set_cursor new_cursor;

  method handle_keypress ev =
    match ev.ev_KeySymString with
    | "Left" -> self#move_cursor `Left
    | "Right" -> self#move_cursor `Right
    | "Up" -> self#move_cursor `Up
    | "Down" -> self#move_cursor `Down
    | _ -> ()


  method sync_bg x y =
    let cell = Xword.get_cell xw x y in
    let is_cursor = (x, y) = (cursor.x, cursor.y) in
    Canvas.configure_rectangle canvas cells.(y).(x).square
      ~fill:(bg_of_cell cell is_cursor)

  method sync_letter x y =
    let cell = Xword.get_cell xw x y in
    Canvas.configure_text canvas cells.(y).(x).letter
      ~text:(letter_of_cell cell)

  method sync_number x y =
    let n = Xword.get_num xw x y in
    let s = if (n = 0) then " " else (string_of_int n) in
    Canvas.configure_text canvas cells.(y).(x).number ~text:s

  method sync_cell x y =
    self#sync_bg x y;
    self#sync_number x y;
    self#sync_letter x y;

end

let xw =
  let xw = Xword.make 15 15 in
  Xword.set_cell xw 4 5 Black;
  xw

let xw_widget = new xw_canvas ~parent:top ~xword:xw

let _ = Printexc.print mainLoop ();;
