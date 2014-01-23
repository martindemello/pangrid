require 'ostruct'

HEADER_FORMAT = "v A12 v V2 A4 v2 A12 c2 v3"
EXT_HEADER_FORMAT = "A4 v2"

FILE_MAGIC = 'ACROSS&DOWN'

class PuzzleFormatError < Exception
end

# various extensions
def read_ltim(s, e)
  m = s.match /^(\d+),(\d+)\0$/
  raise PuzzleFormatError unless m
  e.elapsed = m[0].to_i
  e.stopped = m[1] == "1"
end

def read_rtbl(s, e)
  rx = /(([\d ]\d):(\w+);)/
  m = s.match /^#{rx}*\0$/
  raise PuzzleFormatError unless m
  e.rebus = {}
  s.scan(rx).each {|_, k, v|
    e.rebus[k.to_i] = v
  }
end

def read_gext(s, e)
end

def grbs(s, e)
end

def read_puz(filename)
  s = IO.read(filename, :encoding => "ISO-8859-1")
  # crossword
  x = OpenStruct.new
  # checksums
  c = OpenStruct.new

  i = s.index(FILE_MAGIC)
  raise PuzzleFormatError unless i

  # read the header
  h_start, h_end = i - 2, i - 2 + 0x34
  header = s[h_start .. h_end]

  c.global, _, c.cib, c.masked_low, c.masked_high,
    x.version, _, c.scrambled, _,
    x.width, x.height, x.n_clues, x.puzzletype, x.scrambled_state =
    header.unpack(HEADER_FORMAT)

  # solution and fill = blocks of w*h bytes each
  size = x.width * x.height
  x.solution = s[h_end + 1, size]
  x.fill = s[h_end + size + 1, size]
  s = s[h_end + 2 * size + 1 .. -1]

  # title, author, copyright, clues * n, notes = zero-terminated strings
  x.title, x.author, x.copyright, *x.clues, x.notes, s =
    s.split("\0", x.n_clues + 5)

  # extensions: 8-byte header + len bytes data + \0
  x.extensions = []
  while (s.length > 8) do
    e = OpenStruct.new
    e.section, e.len, e.checksum = s.unpack(EXT_HEADER_FORMAT)
    size = 8 + e.len + 1
    break if s.length < size
    e.data = s[8 ... size]
    x.extensions << e
    s = s[size .. -1]
  end

  [c, x]
end

c, x = read_puz ARGV[0]
p x.n_clues
p x.clues.length
#p x.extensions

x.extensions.each do |e|
  p e.section
  if e.section == "RTBL"
    read_rtbl e.data, e
    p e
  end
end

