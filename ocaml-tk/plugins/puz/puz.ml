open Core_kernel.Std
open Printf
open Types
open Opal
open Puz_types
open Puz_utils

(* String Constants *)
let header_cksum_format = "<BBH H H "
let maskstring = "ICHEATED"
let file_magic = Str.regexp_string "ACROSS&DOWN"
let blacksquare = "."
let extension_header_format = "< 4s  H H "

(* opal parsers *)
let number = many1 digit => implode % int_of_string
let eos = exactly '\000'
let spc = exactly ' '
let word = many1 letter

let process_extension ex =
  let validate_extension ex =
    List.mem ["GRBS"; "RTBL"; "GEXT"; "LTIM"] ex.section
  in

  let read_ltim s =
    let ltim = number >>= fun i ->
        (exactly ',') >>
        number >>= fun j ->
        eos >>
        return (i, j)
    in
    let read s =
      let input = LazyStream.of_string s in
      match parse ltim input with
      | Some (i, j) -> Printf.printf "(%d, %d)" i j
      | None -> print_endline "NO LTIM"
    in
    read s
  in
  print_endline ex.section
(*
  let read_rtbl s =
    let d = ((spc <|> digit) <~> count 1 digit) => implode in
    let entry = d << (exactly ':) <~> (count 1 word) in
    let rtbl = sep_by1 entry (exactly ";") in
    let read s =
      let input = LazyStream.of_string s in
      match parse rtbl input with
      | Some (i, j) -> Printf.printf "(%d, %s)" i j
      | None -> print_endline "NO RTBL"
    in
    read s

  in
  if ex.section = "RTBL" then read_rtbl ex.data
*)


  

let load_puzzle data =
  (* Files may contain some data before the start of the puzzle.
     Use the magic string as a start marker and save the preamble for
     round-tripping *)
  let start =
    try (Str.search_forward file_magic data 0) - 2
    with Not_found -> raise (PuzzleFormatError "Could not find start of puzzle")
  in
  let s = new string_io data in
  let header = s#read (start + 0x34) in
  let puz = Puz_binreader.read_header header start in
  let solution = s#read (puz.width * puz.height) in
  let fill = s#read (puz.width * puz.height) in
  let title = s#read_string in
  let author = s#read_string in
  let copyright = s#read_string in
  let clues = Array.init puz.n_clues (fun i -> s#read_string) in
  let notes = s#read_string in
  let extensions = Puz_binreader.read_extensions s in
  { puz with solution; fill; title; author; copyright; notes;
             extensions; clues = Array.to_list clues
  }

(* puzzle -> xword conversion *)
let cell_of_char c = match c with
  | '.' -> Black
  | ' ' -> Empty
  | c  -> Letter (Char.to_string c)

let unpack_clues xw puzzle =
  let clues = Array.of_list puzzle.clues in
  let ac = ref [] in
  let dn = ref [] in
  let i = ref 0 in
  Xword.renumber
    ~on_ac:(fun n -> ac := clues.(!i) :: !ac; i := !i + 1)
    ~on_dn:(fun n -> dn := clues.(!i) :: !dn; i := !i + 1)
    xw;
  xw.clues.across <- List.rev !ac;
  xw.clues.down <- List.rev !dn

let to_xw puzzle =
  let xw = Xword.make puzzle.height puzzle.width in
  let s = puzzle.solution in
  for y = 0 to xw.rows - 1 do
    for x = 0 to xw.cols - 1 do
      let ix = y * xw.cols + x in
      let cell = cell_of_char s.[ix] in
      Xword.set_cell xw x y cell
    done
  done;
  unpack_clues xw puzzle;
  xw


let _ =
  let fname = "mini.puz" in
  let data = In_channel.read_all fname in
  let puz = load_puzzle data in
  let xw = to_xw puz in
  Xword.inspect xw;
  List.iter puz.extensions process_extension
