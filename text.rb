# Plain text representation
#
# Mostly used for debugging and quick printing of a grid right now, but it
# would be useful to have a minimalist text representation of a grid and clues.
#
# provides:
#   Text : write

require_relative 'xw'

class Text
  def write(xw)
    rows = xw.to_array(:black => '#', :null => ' ')
    rows.map(&:join).join("\n") + "\n"
  end
end
