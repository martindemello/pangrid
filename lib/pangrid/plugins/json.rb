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

  DESCRIPTION = "Simple JSON format"

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

  def read(data)
    json = ::JSON.parse(data)
    xw = XWord.new

    xw.height = json['rows']
    xw.width = json['cols']
    xw.solution = Array.new(xw.height) { Array.new(xw.width) }
    json['cells'].each do |c|
      cell = Cell.new
      s = c['contents']
      cell.solution =
        case s
        when ""; :null
        when "#"; :black
        else
          if s.length == 1
            s
          else
            Rebus.new s
          end
        end
      x, y = c['x'], c['y']
      xw.solution[y][x] = cell
    end
    xw.across_clues = json['across']
    xw.down_clues = json['down']
    xw
  end

end

end
