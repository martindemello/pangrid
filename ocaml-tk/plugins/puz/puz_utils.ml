open Core_kernel.Std
open Puz_types

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
class string_io _string =
  object
    val str = _string
    val mutable pos = 0

    method remaining = String.length str - pos

    method read n =
      pos <- pos + n;
      String.sub str (pos - n) n

    method read_string =
      let i = String.index_from str pos '\000' in
      match i with
      | Some i -> begin
          let s = String.sub str pos (i - pos) in
          pos <- i + 1;
          s
        end
      | None -> raise (PuzzleFormatError "Could not read string")

  end


