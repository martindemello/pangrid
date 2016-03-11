require 'ostruct'

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
    args.each {|k,v| self.send :"#{k}=", v}
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

  def inspect
    case solution
    when :black; '#'
    when :null; '.'
    when Rebus; solution.inspect
    else; solution
    end
  end
end

# solution = Cell[][]
# width, height = int
# across_clues = string[]
# down_clues = string[]
# rebus = { solution => [int, rebus_char] }
class XWord < OpenStruct
  # Clue numbering
  def black?(x, y)
    solution[y][x].black?
  end

  def boundary?(x, y)
    (x < 0) || (y < 0) || (x >= width) || (y >= height) || black?(x, y)
  end

  def across?(x, y)
    boundary?(x - 1, y) && !boundary?(x, y) && !boundary?(x + 1, y)
  end

  def down?(x, y)
    boundary?(x, y - 1) && !boundary?(x, y) && !boundary?(x, y + 1)
  end

  def number
    n, across, down = 1, [], []
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        across << n if across? x, y
        down << n if down? x, y
        if across.last == n || down.last == n
          solution[y][x].number = n
          n += 1
        end
      end
    end
    [across, down]
  end

  def each_cell
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        yield solution[y][x]
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
        when String
          block_given? ? (yield c) : c.to_char
        when Rebus
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
        if self.rebus[s]
          sym, char = self.rebus[s]
          r.symbol = sym.to_s
        else
          k += 1
          self.rebus[r.solution] = [k, r.display_char]
          r.symbol = k.to_s
        end
      end
    end
  end

  def inspect_grid
    number
    solution.map {|row|
      row.map {|c|
        s = c.solution
        o = case s
        when :black
          "#"
        when :null
          "."
        when String
          c.to_char
        when Rebus
          c.to_char
        else
          raise PuzzleFormatError, "Unrecognised cell #{c}"
        end
        if c.number && c.number > 0
          o = "#{c.number} #{o}"
        end
        o = o.rjust(4)
      }.join("|")
    }.join("\n")
  end
end

end # module Pangrid
