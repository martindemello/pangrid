# A plain text list of clues, to be added to a crossword read from another
# file (e.g. a grid from qxw, which has no clues of its own).
#
#   Across
#
#   7 Wonderful view of canal, including outer banks (8)
#   9 Bleed badly after hack's first cut with saw (6)
#
#   Down
#
#   1 Power to limit a settlement (8)
#
# Section headers are "Across" and "Down" (case insensitive, optionally
# decorated, e.g. "**Across**" or "Across:"). Blank lines, and comment lines
# starting with a # (qxw adds a comment header to its answer files), are
# ignored. Each clue starts with its number, which is used to match it to the
# grid, so the clues don't have to be in order.

module Pangrid

class ClueList
  include PluginUtils

  attr_reader :across, :down

  HEADER = /\A[^\w]*(across|down)[^\w]*\z/i
  # The leading clue number, allowing for markup like "**12.**"
  NUMBER = /\A[^\w\s,]*(\d+)\b/

  def initialize
    @across, @down = {}, {}
  end

  # String -> ClueList
  def self.read(data)
    new.tap {|c| c.read(data)}
  end

  def read(data)
    section = nil
    data.each_line.with_index(1) do |line, lineno|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      if (m = line.match(HEADER))
        section = m[1].downcase == "across" ? across : down
        next
      end
      check("Line #{lineno}: clue before an Across or Down header") { section }
      n = line[NUMBER, 1]
      check("Line #{lineno}: clue does not start with a number: #{line}") { n }
      n = n.to_i
      check("Line #{lineno}: duplicate clue #{n}") { !section.key?(n) }
      section[n] = Clue.parse(strip_clue_numbers([line], [n]).first, number: n)
    end
    check("No clues found") { !across.empty? || !down.empty? }
    self
  end

  # Set the crossword's clues, matching clue numbers against the grid.
  def apply(xw)
    a, d = xw.number
    errors = mismatches("across", a, across) + mismatches("down", d, down)
    check("Clues do not match the grid: " + errors.join("; ")) { errors.empty? }
    xw.across_clues = a.map {|n| across[n]}
    xw.down_clues = d.map {|n| down[n]}
    xw
  end

  private

  def mismatches(dir, grid, clues)
    missing = grid - clues.keys
    extra = clues.keys - grid
    errors = []
    errors << "no #{dir} clue for #{missing.join(', ')}" unless missing.empty?
    errors << "#{dir} clue #{extra.join(', ')} not in grid" unless extra.empty?
    errors
  end
end

end # module Pangrid
