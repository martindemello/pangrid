# Exolve (https://github.com/viresh-ratnakar/exolve) is a browser-based
# crossword solver that allows you to embed the crossword and solving software
# in a single HTML file.

module Pangrid

module ExolveWriter
  def write(xw)
    headers = format_headers(xw)
    across, down = xw.number
    grid = format_grid(xw)
    ac = format_clues(across, xw.across_clues)
    dn = format_clues(down, xw.down_clues)
    across = ["exolve-across:"] + indent(ac)
    down = ["exolve-down:"] + indent(dn)
    grid = ["exolve-grid:"] + indent(grid)
    body = headers + grid + across + down
    out = ["exolve-begin"] + indent(body) + ["exolve-end"]
    out.join("\n")
  end

  def format_headers(xw)
    headers = [
      'id', 'replace-with-unique-id',
      'title', xw.title,
      'setter', xw.author,
      'width', xw.width,
      'height', xw.height,
      'copyright', xw.copyright,
      'prelude', xw.preamble
    ]
    headers.each_slice(2).select {|k, v| v}.map {|k, v| "exolve-#{k}: #{v}"}
  end

  def format_clues(numbers, clues)
    numbers.zip(clues).map {|n, c| "#{n.to_s.rjust(2)}. #{c}"}
  end

  def indent(lines)
    lines.map {|x| "  " + x}
  end
end

class ExolveFilled < Plugin
  include ExolveWriter

  DESCRIPTION = "Exolve writer with solutions"

  def format_grid(xw)
    xw.to_array(:black => '.', :null => '0').map(&:join)
  end
end

class ExolveBlank < Plugin
  include ExolveWriter

  DESCRIPTION = "Exolve writer without solutions"

  def format_grid(xw)
    xw.to_array(:black => '.', :null => '0') {|c| 0}.map(&:join)
  end
end

end # module Pangrid
