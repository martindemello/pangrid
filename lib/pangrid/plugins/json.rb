# Json
#
# cell = { x : int, y : int, contents : string }
#
# xword = { rows : int, 
#           cols : int, 
#           cells : [cell],
#           across : [string]
#           down : [string]
#         }

require 'json'

module Pangrid

class Json < Plugin
  def write(xw)
    cells = []
    (0 ... xw.height).each do |y|
      (0 ... xw.width).each do |x|
        cell = xw.solution[y][x]
        s = case cell.solution
            when :black; '#'
            when :null; ''
            when Rebus; cell.solution.inspect
            else; cell.solution
            end

        cells.push({ x: x, y: y, contents: s })
      end
    end

    h = {
      rows: xw.height,
      cols: xw.width,
      cells: cells,
      across: xw.across_clues,
      down: xw.down_clues
    }

    ::JSON.generate(h)
  end
end

end
