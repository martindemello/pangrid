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

  DESCRIPTION = "Reddit format (with filled squares)"

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

  DESCRIPTION = "Reddit format (with blank squares)"

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

  # make a best-attempt effort to strip off the clue number, e.g.
  #   "1\\. Clue", "**1.** Clue", "1 Clue" -> "Clue"
  # clues without the expected number are left as they are.
  def strip_clue(n, clue)
    clue.sub(/\A\W*#{n}\b\W*?\s+/, '').strip
  end

  # The lines following a clue section header, up to the next header
  def clue_section(lines, start, other)
    stop = other > start ? other : lines.length
    lines[(start + 1) ... stop]
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
    check("Could not find grid") { not ix.nil? }
    width = lines[ix].gsub(/\s/, '').split('|').reject(&:empty?).length
    lines = [lines[(ix - 1)]] + lines[(ix + 1) .. -1]
    grid = lines.take_while {|i| is_grid_row(i)}

    clues = lines[grid.length .. -1].map(&:strip).reject(&:empty?)

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
    check("Could not find across clues") { aix }
    check("Could not find down clues") { dix }
    ac = clue_section(clues, aix, dix).take(across.length)
    dn = clue_section(clues, dix, aix).take(down.length)
    xw.across_clues = across.zip(ac).map {|n, c| c && strip_clue(n, c)}.compact
    xw.down_clues = down.zip(dn).map {|n, c| c && strip_clue(n, c)}.compact

    xw
  end

  def grid(xw)
    xw.to_array({:black => '*.*', :null => ' '}) do |c|
      c.number ? "^#{c.number}" : ''
    end
  end
end

end # module Pangrid
