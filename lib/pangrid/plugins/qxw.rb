# Qxw savefile for rectangular grids [http://www.quinapalus.com/qxw.html]

module Pangrid

QXW_GRID_ERROR = "Could not read grid from .qxw file"

class Qxw < Plugin

  DESCRIPTION = "QXW grid reader (rectangular grids only)"

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
    grid = lines.select {|x| x =~ /^SQ /}
    grid.each do |line|
      parts = line.scan(/\w+/)
      check(QXW_GRID_ERROR) { parts.length == 6 || parts.length == 7 }
      col, row, b, c = parts[1].to_i, parts[2].to_i, parts[5].to_i, parts[6]
      cell = Cell.new
      if b == 1
        cell.solution = :black
      elsif c == nil
        cell.solution = :null
      else
        cell.solution = c
      end
      xw.solution[row] ||= []
      xw.solution[row][col] = cell
    end
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
