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

# solution = :black | :null | :void | char | Rebus
#   :null is an empty light (a square whose letter isn't known); :void is a
#   square that is not part of the grid at all (ipuz null, qxw cutouts)
# number = int, filled in by XWord#number
# borders = [:left, :right, :top, :bottom]
# circle, highlight, given, diagramless = bool
#   given: the letter is shown to the solver (exolve "!", ipuz "value")
# color = string, as given in the source file (e.g. "FF0000", "palegreen")
# label = string shown instead of the clue number; labelled squares don't
#         use up a number, and "" means no number at all (exolve "~")
# marks = { "TL" | "T" | "TR" | "L" | "C" | "R" | "BL" | "B" | "BR" => text }
#         small text in the corners or sides of the square (ipuz mark)
class Cell
  attr_accessor :solution, :number, :borders, :circle, :color, :highlight,
                :given, :diagramless, :label, :marks

  def initialize(**args)
    @borders = []
    @marks = {}
    args.each {|k,v| self.send :"#{k}=", v}
  end

  def borders=(b)
    @borders = b || []
  end

  def marks=(m)
    @marks = m || {}
  end

  def black?
    solution == :black
  end

  def void?
    solution == :void
  end

  # Part of a word: not a block or a void square
  def light?
    !black? && !void?
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
    when :void; '_'
    when Rebus; solution.inspect
    else; solution
    end
  end

  alias_method :inspect, :to_w
end

# A nina (a hidden message in the grid): cells = [x, y][], color = string
Nina = Struct.new(:cells, :color)

# A question to answer after solving the grid, e.g. the theme of a meta
# puzzle. text may be nil for a puzzle's final answer (ipuz answer).
Question = Struct.new(:text, :enumeration, :answer)

# A light (an across or down word): number is the clue number, or the
# square's label if it has one
Light = Struct.new(:number, :direction, :x, :y)

# solution = Cell[][]
# width, height = int
# across_clues = Clue[], one per across light, in numbering order
# down_clues = Clue[]
# nodir_clues = Clue[], clues without a direction (exolve nodir, ipuz
#               "Clues"), typically with a label and a list of cells
# rebus = { solution => [int, rebus_char] }
#
# The clue lists also accept strings, which are converted to Clues.
#
# Metadata (all strings unless noted):
#   title, author, editor, copyright, publisher, publication, url
#   date: as given in the source file (ipuz uses mm/dd/yyyy)
#   difficulty
#   id: a unique id for the puzzle (ipuz uniqueid, exolve-id)
#   preamble: instructions shown before solving (ipuz intro, exolve-prelude)
#   notes: notes shown alongside the puzzle (AcrossLite notepad, ipuz notes)
#   explanation: shown after solving (ipuz explanation, exolve-explanations)
#   postscript: text shown below the puzzle (exolve-postscript)
#   annotation: never shown to the solver (ipuz annotation)
#   credits: string[] (exolve-credits)
#   email: contact address(es) for the setter (exolve-email)
#   origin: the program that made the file (ipuz origin, exolve-maker)
#   language: language and script, e.g. "hi Devanagari" (exolve-language)
#   charset: the characters that can be entered (ipuz charset)
#
# Puzzle-wide extras:
#   ninas: Nina[]
#   questions: Question[]
#   misses: { wrong answer => hint } shown when the solver enters a common
#           wrong answer (ipuz misses)
#   alternatives: { [x, y] => letter }[], groups of squares that may all be
#                 filled with these letters instead (exolve-alternatives)
class XWord
  METADATA = %i(title author editor copyright publisher publication url date
                difficulty id preamble notes explanation postscript
                annotation credits email origin language charset)

  EXTRAS = %i(ninas questions misses alternatives)

  # Fields shared by all formats
  COMMON = %i(width height solution across_clues down_clues nodir_clues
              rebus) + METADATA + EXTRAS

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
    circles: "circled squares",
    colors: "coloured squares",
    highlights: "highlighted squares",
    given: "letters given in the grid",
    diagramless: "diagramless squares",
    labels: "non-standard clue numbers",
    marks: "text in the corners of squares",
    void: "squares outside the grid",
    explanations: "clue explanations",
    hints: "clue hints",
    linked_clues: "linked clues",
    nodir_clues: "clues without a direction",
    ninas: "ninas",
    questions: "extra questions",
    final_answer: "a final answer for the puzzle",
    misses: "hints for wrong answers",
    alternatives: "alternative answers"
  }

  # The features this crossword uses
  def features
    cells = solution ? solution.flatten.compact : []
    clues = all_clues
    used = []
    used << :bars if cells.any? {|c| !c.borders.empty?}
    used << :circles if cells.any?(&:circle)
    used << :colors if cells.any?(&:color)
    used << :highlights if cells.any?(&:highlight)
    used << :given if cells.any?(&:given)
    used << :diagramless if cells.any?(&:diagramless)
    used << :labels if cells.any?(&:label)
    used << :marks if cells.any? {|c| !c.marks.empty?}
    used << :void if cells.any?(&:void?)
    used << :explanations if clues.any?(&:explanation)
    used << :hints if clues.any? {|c| !c.hints.empty?}
    used << :linked_clues if clues.any? {|c| !c.linked.empty? || c.parent}
    used << :nodir_clues if !nodir_clues.empty?
    (EXTRAS - [:questions]).each {|f| used << f if self[f] && !self[f].empty?}
    questions = self.questions || []
    used << :questions if questions.any?(&:text)
    used << :final_answer if questions.any? {|q| !q.text}
    used
  end

  # Clue numbering
  def black?(x, y)
    solution[y][x].black?
  end

  def boundary?(x, y)
    (x < 0) || (y < 0) || (x >= width) || (y >= height) || !solution[y][x].light?
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

  # Record each bar on the squares on both sides of it
  def mirror_bars!
    each_cell_with_coords do |x, y, cell|
      right = x + 1 < width && solution[y][x + 1]
      below = y + 1 < height && solution[y + 1][x]
      right.borders |= [:left] if right && cell.has_bar?(:right)
      below.borders |= [:top] if below && cell.has_bar?(:bottom)
      solution[y][x - 1].borders |= [:right] if x > 0 && cell.has_bar?(:left)
      solution[y - 1][x].borders |= [:bottom] if y > 0 && cell.has_bar?(:top)
    end
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

  # [x, y] of the squares in the word starting from a square
  def light_cells(x, y, dir)
    cells = []
    while !boundary?(x, y) do
      cells << [x, y]
      break if word_end?(x, y, dir)
      if dir == :across
        x += 1
      else
        y += 1
      end
    end
    cells
  end

  # Word starting from a square
  def word_from(x, y, dir)
    light_cells(x, y, dir).map {|cx, cy| solution[cy][cx].to_w}.join
  end

  # Number the grid. Returns the across and down clue numbers in order (and,
  # if words is true, the words in the grid). Squares with a label don't use
  # up a number, and their label takes the place of the number.
  def number(words = false)
    n, across, down = 1, [], []
    words_a, words_d = [], []
    @lights = []
    each_cell {|c| c.number = nil}
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        a, d = across?(x, y), down?(x, y)
        next unless a || d
        cell = solution[y][x]
        id = cell.label || n
        if a
          across << id
          words_a << word_from(x, y, :across)
          @lights << Light.new(id, :across, x, y)
        end
        if d
          down << id
          words_d << word_from(x, y, :down)
          @lights << Light.new(id, :down, x, y)
        end
        unless cell.label
          cell.number = n
          n += 1
        end
      end
    end
    words ? [across, down, words_a, words_d] : [across, down]
  end

  # All the lights in grid order, across before down for each square
  def lights
    number
    @lights
  end

  # The light with the given number (or label) and direction
  def light(number, dir)
    lights.find {|l| l.number == number && l.direction == dir}
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
  #
  # Void squares are shown as black ones unless opts[:void] is given.
  def to_array(opts = {})
    opts = {:black => '#', :null => ' '}.merge(opts)
    opts[:void] = opts[:black] unless opts.key?(:void)
    solution.map {|row|
      row.map {|c|
        s = c.solution
        case s
        when :black, :null, :void
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
