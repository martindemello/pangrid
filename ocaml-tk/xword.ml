open Types

type t = {
  rows : int;
  cols : int;
  grid : square array array;
  clues : clues;
}

let make rows cols =
  let sq = { cell = Empty; num = 0 } in
  {
    rows = rows;
    cols = cols;
    grid = Array.make_matrix rows cols sq;
    clues = { across = []; down = [] }
  }

let get xw x y = xw.grid.(y).(x)

let set xw x y s = xw.grid.(y).(x) <- s

let get_cell xw x y = (get xw x y).cell

let set_cell xw x y c = xw.grid.(y).(x) <- { xw.grid.(y).(x) with cell = c }

let get_num xw x y = (get xw x y).num

let set_num xw x y n = xw.grid.(y).(x) <- { xw.grid.(y).(x) with num = n }

let is_black xw x y = (get_cell xw x y) = Black

let boundary xw x y =
  (x < 0) || (y < 0) ||
  (x >= xw.cols) || (y >= xw.rows) ||
  is_black xw x y

let non_boundary xw x y = not (boundary xw x y)

let start_across xw x y =
  (boundary xw (x - 1) y) &&
  (non_boundary xw x y) &&
  (non_boundary xw (x + 1) y)

let start_down xw x y =
  (boundary xw x (y - 1)) &&
  (non_boundary xw x y) &&
  (non_boundary xw x (y + 1))

let renumber xw =
  let n = ref 1 in
  let ac = ref [] in
  let dn = ref [] in
  for y = 0 to xw.rows - 1 do
    for x = 0 to xw.cols - 1 do
      let a, d = start_across xw x y, start_down xw x y in
      if a then ac := n :: !ac;
      if d then dn := n :: !dn;
      if (a || d) then begin
        set_num xw x y !n;
        n := !n + 1;
      end
      else
        set_num xw x y 0;
    done
  done;
  (List.rev !ac, List.rev !dn)

let toggle_black xw x y =
  match get_cell xw x y with
  | Black -> set_cell xw x y Empty; true
  | Empty -> set_cell xw x y Black; true
  | _ -> false
