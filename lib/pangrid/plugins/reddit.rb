# Markup used by crosswords.reddit.com

module Pangrid

module RedditWriter
  def write_line(row)
    '|' + row.join('|') + '|'
  end

  def write_table(grid)
    width = grid[0].length
    out = grid.map {|row| write_line(row)}
    sep = write_line(["--"] * width)
    out = [out[0], sep] + out[1..-1]
    out.join("\n") + "\n"
  end

  def format_clues(numbers, clues, indent)
    numbers.zip(clues).map {|n, c| " "*indent + "#{n}. #{c}"}.join("\n\n")
  end

  def write_clues(xw, across, down)
    ac = "**Across**\n\n" + format_clues(across, xw.across_clues, 2)
    dn = "**Down**\n\n" + format_clues(down, xw.down_clues, 2)
    ac + "\n\n" + dn
  end

  def write_xw(xw)
    across, down = xw.number
    write_table(grid(xw)) + "\n\n" + write_clues(xw, across, down) + "\n"
  end
end

class RedditFilled < Plugin
  include RedditWriter

  def write(xw)
    write_xw(xw)
  end

  def grid(xw)
    xw.to_array({:black => '*.*', :null => ' '}) do |c|
      c.to_char.upcase + (c.number ? "^#{c.number}" : '')
    end
  end
end

class RedditBlank < Plugin
  include RedditWriter

  def write(xw)
    write_xw(xw)
  end

  def grid(xw)
    xw.to_array({:black => '*.*', :null => ' '}) do |c|
      c.number ? "^#{c.number}" : ''
    end
  end
end

end # module Pangrid
