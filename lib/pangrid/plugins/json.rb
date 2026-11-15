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
            when Rebus; cell.solution.solution
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
    begin
      json = ::JSON.parse(data)
    rescue ::JSON::ParserError => e
      raise PuzzleFormatError, "Invalid JSON: #{e.message}"
    end
    check("Expected a JSON object") { json.is_a?(Hash) }
    xw = XWord.new

    xw.height = json['rows']
    xw.width = json['cols']
    check("rows and cols must be positive integers") {
      [xw.height, xw.width].all? {|i| i.is_a?(Integer) && i > 0}
    }
    check("cells must be a list") { json['cells'].is_a?(Array) }
    xw.solution = Array.new(xw.height) { Array.new(xw.width) }
    json['cells'].each do |c|
      cell = Cell.new
      s = c['contents']
      x, y = c['x'], c['y']
      check("Cell #{c.inspect} is outside the grid") {
        x.is_a?(Integer) && y.is_a?(Integer) &&
          (0...xw.width).cover?(x) && (0...xw.height).cover?(y)
      }
      check("Cell #{c.inspect} needs string contents") { s.is_a?(String) }
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
      xw.solution[y][x] = cell
    end
    missing = xw.solution.flatten.count(nil)
    check("#{missing} cells are missing from the grid") { missing == 0 }
    xw.across_clues = json['across']
    xw.down_clues = json['down']
    xw
  end

end

end
