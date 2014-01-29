require_relative'xw'

class Text
  def write(xw)
    xw.solution.map {|row|
      row.map {|c|
        s = c.solution
        case s
        when :black
          "#"
        when :null
          ' '
        when String
          c.rebus? ? (c.rebus_char || s[0]) : s
        else
          raise PuzzleFormatError, "Unrecognised cell #{c}"
        end
      }.join
    }.join("\n")
  end
end
