open Printf
open Core_kernel
open Core_kernel.Std
open Types

(* String Constants *)
let header_cksum_format = "<BBH H H "
let maskstring = "ICHEATED"
let file_magic = Str.regexp_string "ACROSS&DOWN"
let blacksquare = "."
let extension_header_format = "< 4s  H H "

(* Datatypes *)

type puzzle_type = [`Normal | `Diagramless]

type solution_state = [`Locked | `Unlocked]

type grid_markup = [`Default | `PreviouslyIncorrect | `Incorrect | `Revealed | `Circled]

type extension_type = [`Rebus | `RebusSolutions | `RebusFill | `Timer | `Markup]

type extension = extension_type * string

type puzzle = {
  preamble: string;
  postscript: string;
  title: string;
  author: string;
  copyright: string;
  width: int;
  height: int;
  n_clues: int;
  version: string;
  fileversion: string;
  scrambled_cksum: int;
  fill: string;
  solution: string;
  clues: string list;
  notes: string;
  extensions: extension list;
  puzzletype: puzzle_type;
  solution_state: solution_state;
  helpers: string list
}

let new_puzzle = {
  preamble = "";
  postscript = "";
  title = "";
  author = "";
  copyright = "";
  width = 0;
  height = 0;
  n_clues = 0;
  version = "1.3";
  fileversion = "1.3";
  scrambled_cksum = 0;
  fill = "";
  solution = "";
  clues = [];
  notes = "";
  extensions = [];
  puzzletype = `Normal;
  solution_state = `Unlocked;
  helpers = [];
}

exception PuzzleFormatError of string

(* CRC checksum for binary format *)
class checksum ~seed =
  object(self)
    val mutable sum = seed

    method sum = sum

    method add_char b =
      let low = sum land 0x001 in
      sum <- sum lsr 1;
      if low = 1 then sum <- sum lor 0x8000;
      sum <- (sum + (Char.to_int b)) land 0xffff

    method add_string s =
      String.iter s self#add_char

    method add_string_0 s =
      if not (String.is_empty s) then begin
        self#add_string s;
        self#add_char '\000'
      end
  end

let checksum_of_string s =
  let c = new checksum 0 in
  c#add_string s;
  c#sum

(* Access a string as an input stream *)
let string_io _string =
  object
    val str = _string
    val mutable pos = 0

    method read n = begin
      pos <- pos + n;
      String.sub str (pos - n) n
    end

    method read_string = begin
      let i = String.index_from str pos '\000' in
      match i with
      | Some i -> begin
          let s = String.sub str pos (i - pos) in
          pos <- i + 1;
          s
        end
      | None -> raise (PuzzleFormatError "Could not read string")
    end
  end

(* Read header from binary .puz *)
let read_header data start =
  let s = Bitstring.bitstring_of_string data in
  bitmatch s with
  | {
      preamble: start * 8 : string;
      checksum: 2 * 8;
      magic: 0xc * 8 : string;
      checksum_cib: 16 : littleendian;
      checksum_low: 32 : littleendian;
      checksum_high: 32 : littleendian;
      version: 32 : string;
      reserved1c : 16;
      scrambled_checksum : 16 : littleendian;
      reserved20 : 0xc * 8 : string;
      width : 8;
      height: 8;
      n_clues: 16 : littleendian;
      puzzle_type: 16 : littleendian;
      scrambled_tag : 16 : littleendian
  } ->
    { new_puzzle with preamble; width; height; version; n_clues }


let load_puzzle data =
  (* Files may contain some data before the start of the puzzle.
     Use the magic string as a start marker and save the preamble for
     round-tripping *)
  let start =
    try (Str.search_forward file_magic data 0) - 2
    with Not_found -> raise (PuzzleFormatError "Could not find start of puzzle")
  in
  let s = string_io data in
  let header = s#read (start + 0x34) in
  let puz = read_header header start in
  let solution = s#read (puz.width * puz.height) in
  let fill = s#read (puz.width * puz.height) in
  let title = s#read_string in
  let author = s#read_string in
  let copyright = s#read_string in
  let clues = Array.init puz.n_clues (fun i -> s#read_string) in
  let notes = s#read_string in
  { puz with solution; fill; title; author; copyright; notes;
    clues = Array.to_list clues
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
  let data = In_channel.read_all "lat140105.puz" in
  let puz = load_puzzle data in
  let xw = to_xw puz in
  Xword.inspect xw
