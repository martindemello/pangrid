require_relative'xw'

class Text
  def write(xw)
    rows = xw.to_array(:black => '#', :null => ' ')
    rows.map(&:join).join("\n") + "\n"
  end
end
