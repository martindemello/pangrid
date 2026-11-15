# Plain text representation
#
# Mostly used for debugging and quick printing of a grid right now, but it
# would be useful to have a minimalist text representation of a grid and clues.
#
# provides:
#   Text : write

module Pangrid

class Text < Plugin

  DESCRIPTION = "Basic text format (mostly for debugging)"

  def write(xw)
    across, down = xw.number
    rows = xw.to_array(:black => '#', :null => '.')
    grid = rows.map(&:join).join("\n") + "\n"
    ac = "Across:\n\n" + format_clues(across, xw.across_clues, 2)
    dn = "Down:\n\n" + format_clues(down, xw.down_clues, 2)
    grid + "\n" + ac + "\n\n" + dn + "\n"
  end

  def format_clues(numbers, clues, indent)
    numbers.zip(clues).map {|n, c| " "*indent + "#{n.to_s.rjust(2)}. #{c}"}.join("\n")
  end
end

end # module Pangrid
