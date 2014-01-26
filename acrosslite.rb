require 'ostruct'

class PuzzleFormatError < Exception
end

def check
  raise PuzzleFormatError unless yield
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
  FILE_MAGIC = "ACROSS&DOWN\0"
  TEXT_HEADINGS = %w( TITLE AUTHOR COPYRIGHT SIZE GRID REBUS ACROSS DOWN NOTEPAD )

  def initialize
    @xw = OpenStruct.new
    @cs = OpenStruct.new
  end

  # binary format
  def read_puz(filename)
    s = IO.read(filename, :encoding => "ISO-8859-1")

    i = s.index(FILE_MAGIC)
    check { i } 

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
      check { EXTENSIONS.include? e.section }
      size = 8 + e.len + 1
      break if s.length < size
      e.data = s[8 ... size]
      self.send(:"read_#{e.section.downcase}", e)
      xw.extensions << e
      s = s[size .. -1]
    end

    # verify checksums
    check { checksums == cs }
  end

  def write_puz
    @cs = checksums
    h = [cs.global, FILE_MAGIC, cs.cib, cs.masked_low, cs.masked_high,
         xw.version + "\0", 0, cs.scrambled, "\0" * 12,
         xw.width, xw.height, xw.n_clues, xw.puzzle_type, xw.scrambled_state]
    header = h.pack(HEADER_FORMAT)
    extensions = xw.extensions.map {|e|
      [e.section, e.len, e.checksum].pack(EXT_HEADER_FORMAT) +
        self.send(:"write_#{e.section.downcase}", e)
    }.join

    strings = [xw.title, xw.author, xw.copyright] + xw.clues + [xw.notes]
    strings = strings.map {|x| x + "\0"}.join

    [header, xw.solution, xw.fill, strings, extensions].map {|x|
      x.force_encoding("ISO-8859-1")
    }.join
  end

  # various extensions
  def get_extension(s)
    return nil unless xw.extensions
    xw.extensions.find {|e| e.section == s}
  end

  def read_ltim(e)
    m = e.data.match /^(\d+),(\d+)\0$/
    check { m }
    e.elapsed = m[1].to_i
    e.stopped = m[2] == "1"
  end

  def write_ltim(e)
    e.elapsed.to_s + "," + (e.stopped ? "1" : "0") + "\0"
  end

  def read_rtbl(e)
    rx = /(([\d ]\d):(\w+);)/
    m = e.data.match /^#{rx}*\0$/
    check { m }
    e.rebus = {}
    e.data.scan(rx).each {|_, k, v|
      e.rebus[k.to_i] = v
    }
  end

  def write_rtbl(e)
    e.rebus.keys.sort.map {|x|
      x.to_s.rjust(2) + ":" + e.rebus[x] + ";"
    }.join + "\0"
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

  # Text format
  def read_text(filename)
    s = IO.readlines(filename).map(&:strip)
    # first line must be <ACROSS PUZZLE>
    check { s.shift == "<ACROSS PUZZLE>" }
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
  end

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
      xw.grid = section.join
    when "REBUS"
      check { section.length > 0 }
      rebus = {}
      # flag list (currently MARK or nothing)
      xw.mark = section[0] == "MARK;"
      section.shift if xw.mark
      section.each do |line|
        check { line =~ /^.+:.+:.$/ }
        sym, long, short = line.split(':')
        rebus[sym] = [long, short]
      end
    when "ACROSS", "DOWN"
      xw.clues ||= []
      xw.clues += section
    else
      puts header
      raise PuzzleFormatError
    end
  end

  def write_text
    across, down = number
    n_across = across.length
    sections = [
      ['TITLE', [xw.title]],
      ['AUTHOR', [xw.author]],
      ['COPYRIGHT', [xw.copyright]],
      ['SIZE', ["#{xw.height}x#{xw.width}"]],
      ['GRID', xw.grid.scan(/#{"."*xw.width}/)],
      ['REBUS', write_text_rebus],
      ['ACROSS', xw.clues[0 ... n_across]],
      ['DOWN', xw.clues[n_across .. -1]],
      ['NOTEPAD', xw.notes.to_s.split("\n")]
    ]
    out = ["<ACROSS PUZZLE>"]
    sections.each do |h, s|
      next if s.nil? || s.empty?
      out << "<#{h}>" 
      s.each {|l| out << " #{l}"}
    end
    out.join("\n")
  end

  def write_text_rebus
    e = get_extension("RTBL")
    out = []
    return out unless e
    out << "MARK;" if xw.mark
    e.rebus.each {|k, v|
      out << "#{k}:#{v[0]}:#{v[1]}"
    }
    out
  end

  # Clue numbering
  def black?(x, y)
    xw.grid[y * xw.width + x] == '.'
  end

  def border?(x, y)
    black?(x, y) || (x < 0) || (y < 0) || (x >= xw.width) || (y >= xw.height)
  end

  def across?(x, y)
    border?(x - 1, y) && !border?(x, y) && !border?(x + 1, y)
  end

  def down?(x, y)
    border?(x, y - 1) && !border?(x, y) && !border?(x, y + 1)
  end

  def number
    n, across, down = 0, [], []
    (0 ... xw.height).each do |y|
      (0 ... xw.width).each do |x|
        across << n if across? x, y
        down << n if down? x, y
        n += 1 if across.last == n || down.last == n
      end
    end
    [across, down]
  end
end

a = AcrossLite.new
a.read_text ARGV[0]
puts a.write_text
