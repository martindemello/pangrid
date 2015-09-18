open Puz_types
open Puz_utils

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


(* read in extensions *)
let read_extensions (s : string_io) =
  let read_extension_header data =
    let s = Bitstring.bitstring_of_string data in
    bitmatch s with
    | {
        section: 4 * 8 : string;
        length: 16 : littleendian;
        checksum: 16 : littleendian
    } -> { data = ""; section; length; checksum }
  in  

  let read_extension s =
    let header = s#read 8 in
    let ex = read_extension_header header in
    let data = s#read (ex.length + 1) in
    { ex with data = data }
  in

  let out = ref [] in
  while s#remaining > 8 do
    out := read_extension s :: !out
  done;
  List.rev !out
