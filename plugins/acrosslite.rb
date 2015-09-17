# AcrossLite is a file format used by the New York Times to distribute crosswords.
#
# Binary format: http://code.google.com/p/puz/
# Text format: http://www.litsoft.com/across/docs/AcrossTextFormat.pdf
#
# provides:
#   AcrossLiteBinary : read, write
#   AcrossLiteText : read, write

require 'ostruct'
require_relative '../xw'

GRID_CHARS = {:black => '.', :null => '.'}

# CRC checksum for binary format
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


# String -> Cell[][]
def unpack_solution(xw, s)
  s.each_char.map {|c|
    Cell.new(:solution => c == '.' ? :black : c)
  }.each_slice(xw.width).to_a
end

# {xw | solution = Cell[][]} -> String
def pack_solution(xw)
  # acrosslite doesn't support non-rectangular grids, so map null squares to
  # black too
  xw.to_array(GRID_CHARS).map(&:join).join
end

# {xw | solution = Cell[][]} -> String
def empty_fill(xw)
  # when converting from another format -> binary we won't typically have fill
  # information, since that is an internal property of the acrosslite player
  grid = xw.to_array(GRID_CHARS) {|c| '-'}
  grid.map(&:join).join
end

# Binary format
class AcrossLiteBinary < Plugin
  # crossword, checksums
  attr_accessor :xw, :cs

  HEADER_FORMAT = "v A12 v V2 A4 v2 A12 c2 v3"
  HEADER_CHECKSUM_FORMAT = "c2 v3"
  EXT_HEADER_FORMAT = "A4 v2"
  EXTENSIONS = %w(LTIM GRBS RTBL GEXT)
  FILE_MAGIC = "ACROSS&DOWN\0"

  def initialize
    @xw = XWord.new
    @cs = OpenStruct.new
    @xw.extensions = []
  end

  def read(data)
    s = data.force_encoding("ISO-8859-1")

    i = s.index(FILE_MAGIC)
    check("Could not recognise AcrossLite binary file") { i }

    # read the header
    h_start, h_end = i - 2, i - 2 + 0x34
    header = s[h_start .. h_end]

    cs.global, _, cs.cib, cs.masked_low, cs.masked_high,
      xw.version, _, cs.scrambled, _,
      xw.width, xw.height, xw.n_clues, xw.puzzle_type, xw.scrambled_state =
      header.unpack(HEADER_FORMAT)

    # solution and fill = blocks of w*h bytes each
    size = xw.width * xw.height
    xw.solution = unpack_solution xw, s[h_end, size]
    xw.fill = s[h_end + size, size]
    s = s[h_end + 2 * size .. -1]

    # title, author, copyright, clues * n, notes = zero-terminated strings
    xw.title, xw.author, xw.copyright, *xw.clues, xw.notes, s =
      s.split("\0", xw.n_clues + 5)

    # extensions: 8-byte header + len bytes data + \0
    while (s.length > 8) do
      e = OpenStruct.new
      e.section, e.len, e.checksum = s.unpack(EXT_HEADER_FORMAT)
      check("Unrecognised extension #{e.section}") { EXTENSIONS.include? e.section }
      size = 8 + e.len + 1
      break if s.length < size
      e.data = s[8 ... size]
      self.send(:"read_#{e.section.downcase}", e)
      xw.extensions << e
      s = s[size .. -1]
    end

    # verify checksums
    check("Failed checksum") { checksums == cs }

    process_extensions
    unpack_clues

    xw
  end

  def write(xw)
    @xw = xw

    # fill in some fields that might not be present (checksums needs this)
    pack_clues
    xw.n_clues = xw.clues.length
    xw.fill ||= empty_fill(xw)
    xw.puzzle_type ||= 1
    xw.scrambled_state ||= 0
    xw.version = "1.3"
    xw.notes ||= ""
    xw.extensions ||= []

    # extensions
    xw.encode_rebus!
    if not xw.rebus.empty?
      # GRBS
      e = OpenStruct.new
      e.section = "GRBS"
      e.grid = xw.to_array({:black => 0, :null => 0}) {|s|
        s.rebus? ? s.solution.symbol.to_i : 0
      }.flatten
      xw.extensions << e
      # RTBL
      e = OpenStruct.new
      e.section = "RTBL"
      e.rebus = {}
      xw.rebus.each do |long, (k, short)|
        e.rebus[k] = [long, short]
      end
      xw.extensions << e
    end

    # calculate checksums
    @cs = checksums

    h = [cs.global, FILE_MAGIC, cs.cib, cs.masked_low, cs.masked_high,
         xw.version + "\0", 0, cs.scrambled, "\0" * 12,
         xw.width, xw.height, xw.n_clues, xw.puzzle_type, xw.scrambled_state]
    header = h.pack(HEADER_FORMAT)

    strings = [xw.title, xw.author, xw.copyright] + xw.clues + [xw.notes]
    strings = strings.map {|x| x + "\0"}.join

    [header, pack_solution(xw), xw.fill, strings, write_extensions].map {|x|
      x.force_encoding("ISO-8859-1")
    }.join
  end

  private
  # sort incoming clues in xw.clues -> across and down
  def unpack_clues
    across, down = xw.number
    clues = across.map {|x| [x, :a]} + down.map {|x| [x, :d]}
    clues.sort!
    xw.across_clues = []
    xw.down_clues = []
    clues.zip(xw.clues).each do |(n, dir), clue|
      if dir == :a
        xw.across_clues << clue
      else
        xw.down_clues << clue
      end
    end
  end

  # combine across and down clues -> xw.clues
  def pack_clues
    across, down = xw.number
    clues = across.map {|x| [x, :a]} + down.map {|x| [x, :d]}
    clues.sort!
    ac, dn = xw.across_clues.dup, xw.down_clues.dup
    xw.clues = []
    clues.each do |n, dir|
      if dir == :a
        xw.clues << ac.shift
      else
        xw.clues << dn.shift
      end
    end
    check("Extra across clue") { ac.empty? }
    check("Extra down clue") { dn.empty? }
  end

  def get_extension(s)
    return nil unless xw.extensions
    xw.extensions.find {|e| e.section == s}
  end

  def process_extensions
    # record these for file inspection, though they're unlikely to be useful
    if (ltim = get_extension("LTIM"))
      xw.time_elapsed = ltim.elapsed
      xw.paused
    end

    # we need both grbs and rtbl
    grbs, rtbl = get_extension("GRBS"), get_extension("RTBL")
    if grbs and rtbl
      grbs.grid.each_with_index do |n, i|
        if n > 0 and (v = rtbl.rebus[n])
          x, y = i % xw.width, i / xw.width
          cell = xw.solution[y][x]
          cell.solution = Rebus.new(v[0])
        end
      end
    end
  end

  def read_ltim(e)
    m = e.data.match /^(\d+),(\d+)\0$/
    check("Could not read extension LTIM") { m }
    e.elapsed = m[1].to_i
    e.stopped = m[2] == "1"
  end

  def write_ltim(e)
    e.elapsed.to_s + "," + (e.stopped ? "1" : "0") + "\0"
  end

  def read_rtbl(e)
    rx = /(([\d ]\d):(\w+);)/
    m = e.data.match /^#{rx}*\0$/
    check("Could not read extension RTBL") { m }
    e.rebus = {}
    e.data.scan(rx).each {|_, k, v|
      e.rebus[k.to_i] = [v, '-']
    }
  end

  def write_rtbl(e)
    e.rebus.keys.sort.map {|x|
      x.to_s.rjust(2) + ":" + e.rebus[x][0] + ";"
    }.join
  end

  def read_gext(e)
    e.grid = e.data.bytes
  end

  def write_gext(e)
    e.grid.map(&:chr).join
  end

  def read_grbs(e)
    e.grid = e.data.bytes.map {|b| b == 0 ? 0 : b - 1 }
  end

  def write_grbs(e)
    e.grid.map {|x| x == 0 ? 0 : x + 1}.map(&:chr).join
  end

  def write_extensions
    xw.extensions.map {|e|
      e.data = self.send(:"write_#{e.section.downcase}", e)
      e.len = e.data.length
      e.data += "\0"
      e.checksum = Checksum.of_string(e.data)
      [e.section, e.len, e.checksum].pack(EXT_HEADER_FORMAT) +
        e.data
    }.join
  end

  # checksums
  def text_checksum(seed)
    c = Checksum.new(seed)
    c.add_string_0 xw.title
    c.add_string_0 xw.author
    c.add_string_0 xw.copyright
    xw.clues.each {|cl| c.add_string cl}
    if (xw.version == '1.3')
      c.add_string_0 xw.notes
    end
    c.sum
  end

  def header_checksum
    h = [xw.width, xw.height, xw.n_clues, xw.puzzle_type, xw.scrambled_state]
    Checksum.of_string h.pack(HEADER_CHECKSUM_FORMAT)
  end

  def global_checksum
    c = Checksum.new header_checksum
    c.add_string pack_solution(xw)
    c.add_string xw.fill
    text_checksum c.sum
  end

  def magic_checksums
    mask = "ICHEATED".bytes
    sums = [
      text_checksum(0),
      Checksum.of_string(xw.fill),
      Checksum.of_string(pack_solution(xw)),
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

# Text format
class AcrossLiteText < Plugin
  attr_accessor :xw, :rebus

  def initialize
    @xw = XWord.new
  end

  def read(data)
    s = data.each_line.map(&:strip)
    # first line must be <ACROSS PUZZLE> or <ACROSS PUZZLE V2>
    xw.version = { "<ACROSS PUZZLE>" => 1, "<ACROSS PUZZLE V2>" => 2 }[s.shift]
    check("Could not recognise Across Lite text file") { !xw.version.nil? }
    header, section = "START", []
    s.each do |line|
      if line =~ /^<(.*)>/
        process_section header, section
        header = $1
        section = []
      else
        section << line
      end
    end
    process_section header, section
    xw
  end

  def write(xw)
    @xw = xw

    # scan the grid for rebus squares and replace them with lookup keys
    xw.encode_rebus!

    sections = [
      ['TITLE', [xw.title]],
      ['AUTHOR', [xw.author]],
      ['COPYRIGHT', [xw.copyright]],
      ['SIZE', ["#{xw.height}x#{xw.width}"]],
      ['GRID', write_grid],
      ['REBUS', write_rebus],
      ['ACROSS', xw.across_clues],
      ['DOWN', xw.down_clues],
      ['NOTEPAD', xw.notes.to_s.split("\n")]
    ]
    out = ["<ACROSS PUZZLE V2>"]
    sections.each do |h, s|
      next if s.nil? || s.empty?
      out << "<#{h}>"
      s.each {|l| out << " #{l}"}
    end
    out.join("\n") + "\n"
  end

  private

  def process_section(header, section)
    case header
    when "START"
      return
    when "TITLE", "AUTHOR", "COPYRIGHT"
      check { section.length == 1 }
      xw[header.downcase] = section[0]
    when "NOTEPAD"
      xw.notes = section.join("\n")
    when "SIZE"
      check { section.length == 1 && section[0] =~ /^\d+x\d+/ }
      xw.height, xw.width = section[0].split('x').map(&:to_i)
    when "GRID"
      check { xw.width && xw.height }
      check { section.length == xw.height }
      check { section.all? {|line| line.length == xw.width } }
      xw.solution = unpack_solution xw, section.join
    when "REBUS"
      check { section.length > 0 }
      check("Text format v1 does not support <REBUS>") {xw.version == 2}
      # flag list (currently MARK or nothing)
      xw.mark = section[0] == "MARK;"
      section.shift if xw.mark
      section.each do |line|
        check { line =~ /^.+:.+:.$/ }
        sym, long, short = line.split(':')
        xw.each_cell do |c|
          if c.solution == sym
            c.solution = Rebus.new(long, short)
          end
        end
      end
      xw.encode_rebus!

    when "ACROSS"
      xw.across_clues = section
    when "DOWN"
      xw.down_clues = section
    else
      raise PuzzleFormatError, "Unrecognised header #{header}"
    end
  end

  def write_grid
    xw.to_array(GRID_CHARS).map(&:join)
  end

  def write_rebus
    out = []
    out << "MARK;" if xw.mark
    xw.rebus.keys.sort.each do |long|
      key, short = xw.rebus[long]
      out << "#{key}:#{long}:#{short}"
    end
    out
  end
end
