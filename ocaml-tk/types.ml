type letter = string

type cell = Black | Empty | Letter of letter | Rebus of string * letter

type square = {
  cell : cell;
  num : int;
}

type clues = {
  mutable across : string list;
  mutable down : string list;
}

type direction = [`Left | `Right | `Up | `Down | `Across | `Bksp_Ac | `Bksp_Dn ]

type xword = {
  rows : int;
  cols : int;
  grid : square array array;
  clues : clues;
}

