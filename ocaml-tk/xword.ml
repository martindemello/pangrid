open Types
open Core_kernel.Std

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

let iteri xw f =
  for y = 0 to xw.rows - 1 do
    for x = 0 to xw.cols - 1 do
      f x y (get_cell xw x y)
    done
  done

let renumber ?(on_ac=ignore) ?(on_dn=ignore) xw =
  let n = ref 1 in
  for y = 0 to xw.rows - 1 do
    for x = 0 to xw.cols - 1 do
      let a, d = start_across xw x y, start_down xw x y in
      if a then on_ac !n;
      if d then on_dn !n;
      if (a || d) then begin
        set_num xw x y !n;
        n := !n + 1;
      end
      else
        set_num xw x y 0;
    done
  done

(* Update the 'symbol' field in every rebus square, so that cells
 * with the same solution have the same symbol. Symbols are
 * integers from 1..
 *
 * Returns a map of solution -> rebus {solution; symbol; ...}
 *)
let encode_rebus xw =
  let m = ref (String.Map.empty) in
  let k = ref 0 in
  iteri xw (fun x y c ->
      match c with
      | Rebus r -> begin
          match Map.find !m r.solution with
          | Some sr -> set_cell xw x y (Rebus sr)
          | None -> begin
              k := !k + 1;
              let nr = { r with symbol = !k } in
              set_cell xw x y (Rebus nr);
              m := Map.add !m ~key:r.solution ~data:r
            end
        end
      | _ -> ()
    );
    m

let clue_numbers xw =
  let ac = ref [] in
  let dn = ref [] in
  renumber
    ~on_ac:(fun n -> ac := n :: !ac)
    ~on_dn:(fun n -> dn := n :: !dn)
    xw;
  List.rev !ac, List.rev !dn

let inspect_grid xw =
  for y = 0 to xw.rows - 1 do
    for x = 0 to xw.cols - 1 do
      let c = match (get_cell xw x y) with
        | Black -> "#"
        | Empty -> "."
        | Letter c -> c
        | Rebus r -> r.display_char
      in
      print_string c;
      print_string " "
    done;
    print_newline ()
  done

let inspect_clues xw =
  let ac, dn = clue_numbers xw in
  let print_clue i clue = Printf.printf "%d. %s\n" i clue in
  print_endline "Across";
  List.iter2_exn ac xw.clues.across print_clue;
  print_endline "Down";
  List.iter2_exn dn xw.clues.down print_clue

let inspect xw =
  inspect_grid xw;
  inspect_clues xw

let toggle_black xw x y =
  match get_cell xw x y with
  | Black -> set_cell xw x y Empty; true
  | Empty -> set_cell xw x y Black; true
  | _ -> false
