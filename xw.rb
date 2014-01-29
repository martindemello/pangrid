require 'ostruct'


class PuzzleFormatError < Exception
end

def check(msg = "")
  raise PuzzleFormatError, msg unless yield
end

# solution = :black | :null | char | string
# number = int
# borders = [:left, :right, :top, :bottom]
# rebus_char: optional character representation of a rebus square
class Cell < OpenStruct
  def black?
    solution == :black
  end

  def has_bar?(s)
    borders.include? s
  end

  def rebus?
    solution.is_a?(String) && solution !~ /^[A-Z]$/
  end

  def to_char
    rebus? ? (rebus_char || solution[0]) : solution
  end
end

class XWord < OpenStruct
  # Clue numbering
  def black?(x, y)
    solution[y][x].black?
  end

  def boundary?(x, y)
    black?(x, y) || (x < 0) || (y < 0) || (x >= width) || (y >= height)
  end

  def across?(x, y)
    boundary?(x - 1, y) && !boundary?(x, y) && !boundary?(x + 1, y)
  end

  def down?(x, y)
    boundary?(x, y - 1) && !boundary?(x, y) && !boundary?(x, y + 1)
  end

  def number
    n, across, down = 0, [], []
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        across << n if across? x, y
        down << n if down? x, y
        n += 1 if across.last == n || down.last == n
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
        else
          raise PuzzleFormatError, "Unrecognised cell #{c}"
        end
      }
    }
  end
end
