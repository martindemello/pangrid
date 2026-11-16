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
    numbers.zip(clues).map {|n, c| "#{n.to_s.rjust(2)} #{c}"}
  end

  def indent(lines)
    lines.map {|x| "  " + x}
  end

  # Exolve marks bars with decorators after a square: | for a bar on the
  # right, _ for a bar underneath and + for both. If the grid has any bars,
  # squares are separated by spaces so that the columns line up.
  def format_grid(xw)
    rows = xw.to_array(:black => '.', :null => '0') {|c| grid_char(c)}
    decorators = rows.each_index.map do |y|
      rows[y].each_index.map do |x|
        right, bottom = xw.bar?(x, y, :right), xw.bar?(x, y, :bottom)
        right && bottom ? '+' : right ? '|' : bottom ? '_' : ' '
      end
    end
    if decorators.flatten.all? {|d| d == ' '}
      rows.map(&:join)
    else
      rows.zip(decorators).map {|r, d| r.zip(d).join.rstrip}
    end
  end
end

module ExolveReader
  def read(data)
    s = data.each_line.map(&:rstrip)
    first = s.index('exolve-begin')
    check("exolve-begin missing") { first }
    last = s.index('exolve-end')
    check("exolve-end missing") { last }
    lines = s[(first + 1)...last]
    xw = XWord.new
    s = sections(lines)
    s.each do |_, field, data|
      if %w(title copyright).include? field
        xw[field] = data
      elsif field == "prelude"
        xw.preamble = data
      elsif field == "setter"
        xw.author = data
      elsif %w(height width).include? field
        xw[field] = data.to_i
      elsif %w(across down).include? field
        xw["#{field}_clues"] = strip_clue_numbers(data)
      elsif field == "grid"
        xw.solution = parse_grid(data)
      end
    end
    check("exolve-grid missing") { xw.solution && !xw.solution.empty? }
    xw.height ||= xw.solution.length
    xw.width ||= xw.solution[0].length
    check("Grid does not match exolve-width/exolve-height " +
          "(#{xw.width}x#{xw.height})") {
      xw.solution.length == xw.height &&
        xw.solution.all? {|row| row.length == xw.width}
    }
    xw
  end

  def sections(lines)
    headers = lines.each.with_index.map do |l, i|
      m = l.match(/^(\s+)exolve-(\w+):(.*)$/)
      if m
        _, indent, field, data = m.to_a
        [i, field, data.strip]
      else
        nil
      end
    end
    headers.compact!
    headers.push([lines.length, "", ""])
    headers.each_cons(2) do |i, j|
      if i[2].empty?
        i[2] = lines[(i[0] + 1)...j[0]].map(&:strip)
      end
    end
    headers.pop
    headers
  end

  def parse_grid_char(char)
    case char
    when '0'; :null
    when '.'; :black
    else; char
    end
  end

  # Each square is a character followed by optional decorators:
  #   | bar after, _ bar under, + both, @ circle, * diagramless
  # Circles and diagramless squares are not supported and are ignored.
  def parse_grid(lines)
    grid = lines.map do |line|
      line.scan(/([^\s|_+@*])([|_+@*]*)/).map do |c, decorators|
        cell = Cell.new(:solution => parse_grid_char(c))
        cell.borders << :right if decorators =~ /[|+]/
        cell.borders << :bottom if decorators =~ /[_+]/
        cell
      end
    end
    mirror_bars(grid)
    grid
  end

  # Record each bar on the squares on both sides of it
  def mirror_bars(grid)
    grid.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        right = row[x + 1]
        below = grid[y + 1] && grid[y + 1][x]
        right.borders |= [:left] if right && cell.has_bar?(:right)
        below.borders |= [:top] if below && cell.has_bar?(:bottom)
      end
    end
  end
end

class ExolveFilled < Plugin
  include ExolveReader
  include ExolveWriter

  DESCRIPTION = "Exolve writer with solutions"

  def grid_char(cell)
    cell.to_char
  end
end

class ExolveBlank < Plugin
  include ExolveWriter

  DESCRIPTION = "Exolve writer without solutions"

  def grid_char(cell)
    '0'
  end
end

end # module Pangrid
