# Qxw savefile for rectangular grids [http://www.quinapalus.com/qxw.html]

module Pangrid

QXW_GRID_ERROR = "Could not read grid from .qxw file"

class Qxw < Plugin

  DESCRIPTION = "QXW grid reader (rectangular grids only)"

  def read_black(xw, lines)
    # Read black cells
    grid = lines.select {|x| x =~ /^SQ /}
    grid.each do |line|
      parts = line.scan(/\w+/)
      check(QXW_GRID_ERROR) { parts.length == 6 || parts.length == 7 }
      _, col, row, _, _, b, _ = parts
      col, row, b = col.to_i, row.to_i, b.to_i
      next if b != 1
      cell = Cell.new
      cell.solution = :black
      xw.solution[row] ||= []
      xw.solution[row][col] = cell
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
    read_filled(xw, lines)
    read_black(xw, lines)
    check(QXW_GRID_ERROR) { xw.solution.length == xw.height }
    check(QXW_GRID_ERROR) { xw.solution.all? {|i| i.compact.length == xw.width} }

    # Placeholder clues
    _, _, words_a, words_d = xw.number(true)
    xw.across_clues = words_a.map {|i| "[#{i}]" }
    xw.down_clues = words_d.map {|i| "[#{i}]" }

    xw
  end
end

end # module Pangrid
