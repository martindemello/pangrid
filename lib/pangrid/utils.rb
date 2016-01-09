module Pangrid

module PluginUtils
  def check(msg = "")
    raise PuzzleFormatError, msg unless yield
  end
end

end # module Pangrid
