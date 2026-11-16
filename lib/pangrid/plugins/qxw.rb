# Qxw savefile for rectangular grids [http://www.quinapalus.com/qxw.html]

module Pangrid

QXW_GRID_ERROR = "Could not read grid from .qxw file"

class Qxw < Plugin

  DESCRIPTION = "QXW grid reader (rectangular grids only)"
  FEATURES = [:bars]

  # Square lines have the format
  #   SQ <x> <y> <bars> <merge> <flags> <char>
  # bars: bit 0 = bar on the right edge, bit 1 = bar on the bottom edge
  # flags: bit 0 = block
  def read_squares(lines)
    lines.select {|x| x =~ /^SQ /}.map do |line|
      parts = line.scan(/\w+/)
      check(QXW_GRID_ERROR) { parts.length == 6 || parts.length == 7 }
      _, col, row, bars, _, flags, _ = parts
      [col, row, bars, flags].map(&:to_i)
    end
  end

  def read_black(xw, squares)
    squares.each do |col, row, _, flags|
      next if flags & 1 == 0
      xw.solution[row] ||= []
      xw.solution[row][col] = Cell.new(solution: :black)
    end
  end

  # Each bar is stored once, on the square to its left or above it; record
  # it on both squares it separates.
  def read_bars(xw, squares)
    add = lambda do |col, row, side|
      cell = xw.solution[row] && xw.solution[row][col]
      cell.borders |= [side] if cell
    end
    squares.each do |col, row, bars, _|
      next if xw.boundary?(col, row)
      if bars & 1 != 0 && !xw.boundary?(col + 1, row)
        add.(col, row, :right)
        add.(col + 1, row, :left)
      end
      if bars & 2 != 0 && !xw.boundary?(col, row + 1)
        add.(col, row, :bottom)
        add.(col, row + 1, :top)
      end
    end
  end

  def read_filled(xw, lines)
    # Read filled cells
    grid = lines.select {|x| x =~ /^SQCT /}
    grid.each do |line|
      parts = line.scan(/\w+/)
      check(QXW_GRID_ERROR) { parts.length == 4 || parts.length == 5 }
      _, col, row, d, c = parts
      col, row, d = col.to_i, row.to_i, d.to_i
      next if d != 0  # different char per direction, not supported for now
      cell = Cell.new
      if c == nil
        cell.solution = :null
      else
        cell.solution = c
      end
      xw.solution[row] ||= []
      xw.solution[row][col] = cell
    end
  end

  def read(data)
    xw = XWord.new
    lines = data.lines.map(&:chomp)
    gp = lines.find {|x| x =~ /^GP( \d+){6}$/}
    check("Could not read grid size from .qxw file") { gp }
    type, w, h, _ = gp.scan(/\d+/).map(&:to_i)
    check("Only rectangular grids are supported") { type == 0 }
    xw.width = w
    xw.height = h
    xw.solution = []
    squares = read_squares(lines)
    read_filled(xw, lines)
    read_black(xw, squares)
    check(QXW_GRID_ERROR) { xw.solution.length == xw.height }
    check(QXW_GRID_ERROR) { xw.solution.all? {|i| i.compact.length == xw.width} }
    read_bars(xw, squares)

    # Placeholder clues
    _, _, words_a, words_d = xw.number(true)
    xw.across_clues = words_a.map {|i| "[#{i}]" }
    xw.down_clues = words_d.map {|i| "[#{i}]" }

    xw
  end
end

end # module Pangrid
