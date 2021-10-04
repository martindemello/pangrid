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
      if %w(title setter copyright prelude).include? field
        xw[field] = data
      elsif %w(height width).include? field
        xw[field] = data.to_i
      elsif %(across down).include? field
        xw["#{field}_clues"] = data
      elsif field == "grid"
        xw.solution = parse_grid(data)
      end
    end
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

  def parse_grid(lines)
    grid = lines.map(&:strip).map {|x| x.split(//)}
    grid.map do |col|
      col.map do |c|
        Cell.new(:solution => parse_grid_char(c))
      end
    end
  end
end

class ExolveFilled < Plugin
  include ExolveReader
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
