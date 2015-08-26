# Plain text representation
#
# Mostly used for debugging and quick printing of a grid right now, but it
# would be useful to have a minimalist text representation of a grid and clues.
#
# provides:
#   Text : write

require_relative 'xw'

class Text < Plugin
  def write(xw)
    rows = xw.to_array(:black => '#', :null => ' ')
    rows.map(&:join).join("\n") + "\n"
  end

  # rename to 'read' when this is complete
  def read_grid(data)
    s = data.each_line.map(&:strip)
    m = s[0].match(/^Grid (\d+) (\d+)$/)
    check("Grid line missing") { m }
    xw.height, xw.width = m[1].to_i, m[2].to_i
  end
end
