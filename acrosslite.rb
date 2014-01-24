require 'ostruct'

class PuzzleFormatError < Exception
end

# CRC checksum
class Checksum
  attr_accessor :sum

  def self.of_string s
    c = self.new(0)
    c.add_string s
    c.sum
  end

  def initialize(seed)
    @sum = seed
  end

  def add_char(b)
    low = sum & 0x0001
    @sum = sum >> 1
    @sum = sum | 0x8000 if low == 1
    @sum = (sum + b) & 0xffff
  end

  def add_string(s)
    s.bytes.map {|b| add_char b}
  end

  def add_string_0(s)
    add_string (s + "\0") unless s.empty?
  end
end

class AcrossLite
  # crossword, checksums
  attr_accessor :xw, :cs

  HEADER_FORMAT = "v A12 v V2 A4 v2 A12 c2 v3"
  HEADER_CHECKSUM_FORMAT = "c2 v3"
  EXT_HEADER_FORMAT = "A4 v2"
  EXTENSIONS = %w(LTIM GRBS RTBL GEXT)
  FILE_MAGIC = 'ACROSS&DOWN'

  def initialize
    @xw = OpenStruct.new
    @cs = OpenStruct.new
  end

  def read_puz(filename)
    s = IO.read(filename, :encoding => "ISO-8859-1")

    i = s.index(FILE_MAGIC)
    raise PuzzleFormatError unless i

    # read the header
    h_start, h_end = i - 2, i - 2 + 0x34
    header = s[h_start .. h_end]

    cs.global, _, cs.cib, cs.masked_low, cs.masked_high,
      xw.version, _, cs.scrambled, _,
      xw.width, xw.height, xw.n_clues, xw.puzzle_type, xw.scrambled_state =
      header.unpack(HEADER_FORMAT)

    # solution and fill = blocks of w*h bytes each
    size = xw.width * xw.height
    xw.solution = s[h_end, size]
    xw.fill = s[h_end + size, size]
    s = s[h_end + 2 * size .. -1]

    # title, author, copyright, clues * n, notes = zero-terminated strings
    xw.title, xw.author, xw.copyright, *xw.clues, xw.notes, s =
      s.split("\0", xw.n_clues + 5)

    # extensions: 8-byte header + len bytes data + \0
    xw.extensions = []
    while (s.length > 8) do
      e = OpenStruct.new
      e.section, e.len, e.checksum = s.unpack(EXT_HEADER_FORMAT)
      raise PuzzleFormatError unless EXTENSIONS.include? e.section
      size = 8 + e.len + 1
      break if s.length < size
      e.data = s[8 ... size]
      self.send(:"read_#{e.section.downcase}", e)
      xw.extensions << e
      s = s[size .. -1]
    end

    # verify checksums
    raise PuzzleFormatError unless checksums == cs
  end

  # various extensions
  def read_ltim(e)
    m = e.data.match /^(\d+),(\d+)\0$/
    raise PuzzleFormatError unless m
    e.elapsed = m[0].to_i
    e.stopped = m[1] == "1"
  end

  def read_rtbl(e)
    rx = /(([\d ]\d):(\w+);)/
    m = e.data.match /^#{rx}*\0$/
    raise PuzzleFormatError unless m
    e.rebus = {}
    e.data.scan(rx).each {|_, k, v|
      e.rebus[k.to_i] = v
    }
  end

  def read_gext(e)
    e.grid = e.data.bytes
  end

  def read_grbs(e)
    e.grid = e.data.bytes.map {|b|
      b == 0 ? b : b - 1
    }
  end

  # checksums
  def text_checksum(seed)
    c = Checksum.new(seed)
    c.add_string_0 xw.title
    c.add_string_0 xw.author
    c.add_string_0 xw.copyright
    xw.clues.each {|cl| c.add_string cl}
    c.add_string_0 xw.notes
    c.sum
  end

  def header_checksum
    h = [xw.width, xw.height, xw.n_clues, xw.puzzle_type, xw.scrambled_state]
    Checksum.of_string h.pack(HEADER_CHECKSUM_FORMAT)
  end

  def global_checksum
    c = Checksum.new header_checksum
    c.add_string xw.solution
    c.add_string xw.fill
    text_checksum c.sum
  end

  def magic_checksums
    mask = "ICHEATED".bytes
    sums = [
      text_checksum(0),
      Checksum.of_string(xw.fill),
      Checksum.of_string(xw.solution),
      header_checksum
    ]

    l, h = 0, 0
    sums.each_with_index do |sum, i|
      l = (l << 8) | (mask[3 - i] ^ (sum & 0xff))
      h = (h << 8) | (mask[7 - i] ^ (sum >> 8))
    end
    [l, h]
  end

  def checksums
    c = OpenStruct.new
    c.masked_low, c.masked_high = magic_checksums
    c.cib = header_checksum
    c.global = global_checksum
    c.scrambled = 0
    c
  end
end

a = AcrossLite.new
a.read_puz ARGV[0]
