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
    numbers.zip(clues).map {|n, c| " "*indent + "#{n}\\. #{c}"}.join("\n\n")
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

  def is_grid_row(line)
    line = line.gsub(/\s/, '')
    ix = line.index('|')
    return false unless ix
    c = line[0...ix]
    c == "" || c == "*.*" || c =~ /^(\^\d+)?[[:alpha:]]*$/ # allow partially filled grids
  end

  # make a best-attempt effort to strip off the clue number
  def strip_clues(nums, clues)
    nums.zip(clues).each_with_index.map do |(n, cl), i|
      b = cl.index(n.to_s)
      if b
        e = b + n.to_s.length
        if cl[0...b] =~ /\W*/ and cl[e + 1] =~ /\W/
          cl[e+1 .. -1].sub(/^\W*\s/, '').strip
        else
          cl.strip
        end
      end
    end
  end

  def read(data)
    xw = XWord.new
    lines = data.lines.map(&:chomp)

    # split input into grid and clues
    #
    # grid format is from the reddit table markup:
    # cell|cell|...    # table header; first row for us
    # --|--|...        # alignment markers; drop this
    # cell|cell|...    # rest of xword
    #
    # we have to be careful about leading/trailing |s
    ix = lines.find_index {|row| row =~ /^[|\s-]+$/}
    width = lines[ix].gsub(/\s/, '').split('|').reject(&:empty?).length
    lines = [lines[(ix - 1)]] + lines[(ix + 1) .. -1]
    grid = lines.take_while {|i| is_grid_row(i)}

    clues = lines[grid.length .. -1]
    clues = lines.reject {|i| i.strip.empty?}

    # strip leading |s
    grid = grid.map {|line| line.sub(/^\|/, '')}
    grid = grid.map {|line| line.split("|", -1)[0..(width-1)]}
    grid = grid.map {|line| line.map(&:strip)}
    xw.width = grid[0].length
    xw.height = grid.length
    xw.solution = []
    check("Grid is not rectangular") { grid.all? {|i| i.length == xw.width} }
    grid = grid.map do |row|
      xw.solution << row.map do |c|
        cell = Cell.new
        if c == '*.*'
          cell.solution = :black
        elsif c =~ /[[:alpha:]]/
          cell.solution = c.gsub(/[^[:alpha:]]/, '')
        else
          cell.solution = :null
        end
        cell
      end
    end

    # Clues
    across, down = xw.number
    aix = clues.find_index {|row| row =~ /^\W*across/i}
    dix = clues.find_index {|row| row =~ /^\W*down/i}
    xw.across_clues = clues[(aix + 1) .. (aix + across.length)]
    xw.down_clues = clues[(dix + 1) .. (dix + down.length)]
    xw.across_clues = strip_clues(across, xw.across_clues)
    xw.down_clues = strip_clues(down, xw.down_clues)

    xw
  end

  def grid(xw)
    xw.to_array({:black => '*.*', :null => ' '}) do |c|
      c.number ? "^#{c.number}" : ''
    end
  end
end

end # module Pangrid
