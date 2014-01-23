require 'ostruct'

HEADER_FORMAT = "v A12 v V2 A4 v2 A12 c c v v v"

FILE_MAGIC = 'ACROSS&DOWN'

class PuzzleFormatError < Exception
end

def read_puz(filename)
  s = IO.read(filename, :encoding => "ISO-8859-1")
  # crossword
  x = OpenStruct.new
  # checksums
  c = OpenStruct.new

  i = s.index(FILE_MAGIC)
  raise PuzzleFormatError unless i

  header = s[(i - 2) .. (i - 2 + 0x34)]
  out = header.unpack(HEADER_FORMAT)

  c.global, _, c.cib, c.masked_low, c.masked_high,
    x.version, _, c.scrambled, _,
    x.width, x.height, x.n_clues, x.puzzletype, x.scrambled_state =
    header.unpack(HEADER_FORMAT)

  [c, x]
end

p read_puz ARGV[0]
