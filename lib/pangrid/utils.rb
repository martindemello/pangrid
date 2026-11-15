module Pangrid

module PluginUtils
  def check(msg = "")
    raise PuzzleFormatError, msg unless yield
  end

  # Strip leading clue numbers from a list of clues, e.g.
  #   "1. Clue", "1\\. Clue", "**1.** Clue", "1 Clue" -> "Clue"
  #
  # If `numbers` is given, clues[i] only has numbers[i] stripped, and clues
  # that don't start with their expected number are left as they are.
  # Otherwise any leading number is stripped.
  #
  # The number must be a whole word followed by whitespace, so "1984 author"
  # is not clue 1, and linked clues like "1, 5 Clue" are left alone.
  def strip_clue_numbers(clues, numbers = nil)
    clues.each_with_index.map do |clue, i|
      next clue.strip if numbers && numbers[i].nil?
      n = numbers ? Regexp.escape(numbers[i].to_s) : '\d+'
      clue.sub(/\A\s*[^\w\s,]*#{n}\b[^\w\s,]*\s+/, '').strip
    end
  end
end

end # module Pangrid
