# CSV representation
#
# Useful if you develop your grid in a spreadsheet, for example.
#
# Expected header format:
#
# Width: 15, Height: 15, Offset: 0, Black: ., Empty: -, Clues: 3
#
# detailing
# - the width, height and starting column of the
# grid
# - the characters representing black and empty squares
# - the column in which the clues are in after the
# grid.
#
#
# Blank rows are ignored, as are all rows before the
# header, and rows after the grid with nothing in
# the clue column.
#
# provides:
#   CSV: read

require 'csv'

module Pangrid

class CSV < Plugin

  DESCRIPTION = "CSV reader (see source comments for format)"

  def read(data)
    s = ::CSV.parse(data)
    s.reject! {|row| row.compact.empty?}
    while s[0] && s[0][0] !~ /^Width:/i do
      s.shift
    end
    check("No header row found. Header needs a 'Width: ' cell in the first column.") { !s.empty? }
    xw = XWord.new
    h = s.shift.map {|c| c.split(/:\s*/)}
    header = OpenStruct.new
    h.each do |k, v|
      header[k.downcase] = v
    end

    header.clues = header.clues.to_i
    xw.width = header.width.to_i
    xw.height = header.height.to_i
    xw.solution = []
    xw.height.times do
      row = s.shift
      check("Row does not have #{xw.width} cells: \n" +
            row.join(',')) { row.length == xw.width }
      xw.solution << row.map do |c|
        cell = Cell.new
        if c == header.black
          cell.solution = :black
        elsif c == header.empty or c == nil
          cell.solution = :null
        else
          cell.solution = c.gsub /[^[:alpha:]]/, ''
        end
        cell
      end
    end

    xw.clues = []
    s.each do |row|
      if row[header.clues]
        xw.clues << row[header.clues]
      end
    end
    unpack_clues(xw)
    xw
  end

  private
  def unpack_clues(xw)
    across, down = xw.number
    n_across = across.length
    xw.across_clues = xw.clues[0 ... n_across]
    xw.down_clues = xw.clues[n_across .. -1]
  end
end

end # module Pangrid
