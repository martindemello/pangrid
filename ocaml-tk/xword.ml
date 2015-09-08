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

let get g (x, y) = g.grid.(y).(x)

let set g (x, y) s = g.grid.(y).(x) <- s

let set_cell g (x, y) c = g.grid.(y).(x) <- { g.grid.(y).(x) with cell = c }

let set_num g (x, y) n = g.grid.(y).(x) <- { g.grid.(y).(x) with num = n }

let is_black g p = (get g p).cell = Black

let boundary g (x, y) =
  (x < 0) || (y < 0) ||
  (x >= g.cols) || (y >= g.rows) ||
  is_black g (x, y)
                      
let non_boundary g p = not (boundary g p)

let start_across g x y =
  (boundary g (x - 1, y)) &&
  (non_boundary g (x, y)) &&
  (non_boundary g (x + 1, y)) 

let start_down g x y =
  (boundary g (x, y - 1)) &&
  (non_boundary g (x, y)) &&
  (non_boundary g (x, y + 1))

let renumber g =
  let n = ref 1 in
  let ac = ref [] in
  let dn = ref [] in
  for y = 0 to g.rows - 1 do
    for x = 0 to g.cols - 1 do
      let a, d = start_across g x y, start_down g x y in
      if a then ac := n :: !ac;
      if d then dn := n :: !dn;
      if (a || d) then begin
        set_num g (x, y) !n;
        n := !n + 1;
      end
    done
  done;
  (List.rev !ac, List.rev !dn)
