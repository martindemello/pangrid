require_relative 'clue'

module Pangrid

class PuzzleFormatError < StandardError
end

# symbol: the symbol representing the solution in the grid
#         (populated by xword.encode_rebus!)
# solution: the word the symbol represents
# display_char: optional character representation of a rebus square
class Rebus
  attr_accessor :symbol, :solution, :display_char

  def initialize(str, char = nil)
    @symbol = nil
    @solution = str
    @display_char = char || str[0]
  end

  def to_char
    symbol || display_char
  end

  def inspect
    "[#{symbol}|#{solution}]"
  end
end

# solution = :black | :null | char | Rebus
# number = int
# borders = [:left, :right, :top, :bottom]
class Cell
  attr_accessor :solution, :number, :borders

  def initialize(**args)
    @borders = []
    args.each {|k,v| self.send :"#{k}=", v}
  end

  def borders=(b)
    @borders = b || []
  end

  def black?
    solution == :black
  end

  def has_bar?(s)
    borders.include? s
  end

  def rebus?
    solution.is_a?(Rebus)
  end

  def to_char
    rebus? ? solution.to_char : solution
  end

  def to_w
    case solution
    when :black; '#'
    when :null; '.'
    when Rebus; solution.inspect
    else; solution
    end
  end

  alias_method :inspect, :to_w
end

# solution = Cell[][]
# width, height = int
# across_clues = Clue[], one per across light, in numbering order
# down_clues = Clue[]
# nodir_clues = Clue[], clues without a direction (exolve nodir, ipuz
#               "Clues"), typically with a label and a list of cells
# rebus = { solution => [int, rebus_char] }
#
# The clue lists also accept strings, which are converted to Clues.
class XWord
  # Metadata shared by all formats
  COMMON = %i(width height solution across_clues down_clues nodir_clues
              title author copyright notes preamble rebus)

  # AcrossLite binary format fields
  #   clues: across and down clues interleaved in numerical order
  #   fill: the solver's progress
  #   mark: AcrossLite text format rebus flag
  ACROSSLITE = %i(clues n_clues fill version puzzle_type scrambled_state
                  extensions mark time_elapsed)

  ATTRIBUTES = COMMON + ACROSSLITE

  attr_accessor(*ATTRIBUTES)

  # Unknown attributes raise NoMethodError rather than being silently
  # accepted, so that typos show up immediately.
  def initialize(**args)
    @across_clues = []
    @down_clues = []
    @nodir_clues = []
    args.each {|k, v| self[k] = v}
  end

  # Writers can rely on the clue lists being arrays of Clues
  %i(across_clues down_clues nodir_clues).each do |list|
    define_method(:"#{list}=") do |clues|
      instance_variable_set(:"@#{list}", (clues || []).map {|c| Clue.coerce(c)})
    end
  end

  def all_clues
    (across_clues + down_clues + nodir_clues).compact
  end

  def [](k)
    check_attribute(k)
    public_send(k)
  end

  def []=(k, v)
    check_attribute(k)
    public_send(:"#{k}=", v)
  end

  def to_h
    ATTRIBUTES.to_h {|a| [a, public_send(a)]}.compact.reject {|k, v|
      k == :nodir_clues && v.empty?
    }
  end

  # Grid features that not every format can represent. Plugins list the ones
  # they support in Plugin::FEATURES.
  FEATURES = {
    bars: "bars between squares",
    explanations: "clue explanations",
    hints: "clue hints",
    linked_clues: "linked clues",
    nodir_clues: "clues without a direction"
  }

  # The features this crossword uses
  def features
    cells = solution ? solution.flatten.compact : []
    clues = all_clues
    used = []
    used << :bars if cells.any? {|c| !c.borders.empty?}
    used << :explanations if clues.any?(&:explanation)
    used << :hints if clues.any? {|c| !c.hints.empty?}
    used << :linked_clues if clues.any? {|c| !c.linked.empty? || c.parent}
    used << :nodir_clues if !nodir_clues.empty?
    used
  end

  # Clue numbering
  def black?(x, y)
    solution[y][x].black?
  end

  def boundary?(x, y)
    (x < 0) || (y < 0) || (x >= width) || (y >= height) || black?(x, y)
  end

  OPPOSITE = {left: :right, right: :left, top: :bottom, bottom: :top}
  NEIGHBOUR = {left: [-1, 0], right: [1, 0], top: [0, -1], bottom: [0, 1]}

  # Is there a bar on the given side of square (x, y)? A bar may be recorded
  # on either of the two squares it separates.
  def bar?(x, y, side)
    return false if boundary?(x, y)
    return true if solution[y][x].has_bar?(side)
    dx, dy = NEIGHBOUR[side]
    nx, ny = x + dx, y + dy
    !boundary?(nx, ny) && solution[ny][nx].has_bar?(OPPOSITE[side])
  end

  # Does a word in direction dir end after square (x, y)?
  def word_end?(x, y, dir)
    if dir == :across
      boundary?(x + 1, y) || bar?(x, y, :right)
    else
      boundary?(x, y + 1) || bar?(x, y, :bottom)
    end
  end

  def across?(x, y)
    (boundary?(x - 1, y) || bar?(x, y, :left)) &&
      !boundary?(x, y) && !word_end?(x, y, :across)
  end

  def down?(x, y)
    (boundary?(x, y - 1) || bar?(x, y, :top)) &&
      !boundary?(x, y) && !word_end?(x, y, :down)
  end

  # Word starting from a square
  def word_from(x, y, dir)
    s = ""
    while !boundary?(x, y) do
      s += solution[y][x].to_w
      break if word_end?(x, y, dir)
      if dir == :across
        x += 1
      else
        y += 1
      end
    end
    s
  end

  def number(words = false)
    n, across, down = 1, [], []
    words_a, words_d = [], []
    each_cell {|c| c.number = nil}
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        if across? x, y
          across << n
          words_a << word_from(x, y, :across)
        end
        if down? x, y
          down << n
          words_d << word_from(x, y, :down)
        end
        if across.last == n || down.last == n
          solution[y][x].number = n
          n += 1
        end
      end
    end
    words ? [across, down, words_a, words_d] : [across, down]
  end

  def each_cell
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        yield solution[y][x]
      end
    end
  end

  def each_cell_with_coords
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        yield [x, y, solution[y][x]]
      end
    end
  end

  # {:black => char, :null => char} -> Any[][]
  def to_array(opts = {})
    opts = {:black => '#', :null => ' '}.merge(opts)
    solution.map {|row|
      row.map {|c|
        s = c.solution
        case s
        when :black, :null
          opts[s]
        when String, Rebus
          block_given? ? (yield c) : c.to_char
        else
          raise PuzzleFormatError, "Unrecognised cell #{c}"
        end
      }
    }
  end

  # Collect a hash of rebus solutions, each mapped to an integer.
  def encode_rebus!
    k = 0
    self.rebus = {}
    each_cell do |c|
      if c.rebus?
        r = c.solution
        if self.rebus[r.solution]
          sym, _ = self.rebus[r.solution]
          r.symbol = sym.to_s
        else
          k += 1
          self.rebus[r.solution] = [k, r.display_char]
          r.symbol = k.to_s
        end
      end
    end
  end

  def check_attribute(k)
    unless ATTRIBUTES.include?(k.to_sym)
      raise NoMethodError, "unknown XWord attribute #{k}"
    end
  end

  def inspect_grid
    number
    to_array(:black => '#', :null => '.') {|c|
      c.number ? "#{c.number} #{c.to_char}" : c.to_char
    }.map {|row|
      row.map {|o| o.rjust(4)}.join("|")
    }.join("\n")
  end
end

end # module Pangrid
