# Markup used by crosswords.reddit.com

require_relative '../xw'

module RedditTableWriter
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
end

class RedditFilled < Plugin
  include RedditTableWriter

  def write(xw)
    xw.number
    grid = xw.to_array({:black => '*.*', :null => ' '}) do |c|
      c.to_char.upcase + (c.number ? "^#{c.number}" : '')
    end

    write_table(grid)
  end
end

class RedditBlank < Plugin
  include RedditTableWriter

  def write(xw)
    xw.number
    grid = xw.to_array({:black => '*.*', :null => ' '}) do |c|
      c.number ? "^#{c.number}" : ''
    end

    write_table(grid)
  end
end
