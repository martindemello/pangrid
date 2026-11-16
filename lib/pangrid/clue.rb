module Pangrid

# A reference to another clue, e.g. the "5" in a linked clue "1, 5 Clue".
# direction is :across, :down, or nil for the same direction as the clue
# containing the reference.
ClueRef = Struct.new(:number, :direction) do
  def to_s
    number.to_s + {across: "a", down: "d"}.fetch(direction, "")
  end
end

# A clue. Simple formats just use the clue text, via to_s; richer formats
# (exolve, ipuz) can fill in the other fields.
#
# number:      the clue number, if known
# label:       a label shown instead of the number (e.g. "F" for "[F] Clue")
# text:        the clue itself, without number or enumeration
# enumeration: e.g. "4,3" or "5-2"
# explanation: shown after the puzzle is solved (exolve "anno")
# answer:      the answer, if it isn't just the letters in the grid
# hints:       hints, revealed one at a time
# concise:     a shorter version of the clue
# linked:      ClueRefs to the other clues in a linked clue ("1, 5, 2d")
# parent:      for the later parts of a linked clue, a ClueRef to the
#              first part, which holds the clue text
# references:  ClueRefs to other clues this clue mentions
# cells:       [x, y] squares of the answer, for clues not placed by
#              numbering (e.g. exolve nodir clues, ipuz zones)
# tags, type, image, highlight: ipuz metadata
class Clue
  FIELDS = %i(number label text enumeration explanation answer hints concise
              linked parent references cells tags type image highlight)

  attr_accessor(*FIELDS)

  # Fields that default to (and are never nil instead of) an empty list
  LISTS = %i(hints linked references cells tags)

  # Enumerations follow the rules exolve uses. The usual kind is numeric:
  # numbers, commas, hyphens, apostrophes, periods and spaces, e.g. "4,3",
  # "5-2", "2'1", "4.3". An enumeration can also count words or letters
  # ("8, 2 words", "two words", "7, 2w", "6 letters"), contain a "?", or say
  # that the answer is an abbreviation or acronym.
  NUMERIC_ENUM = /\A\d[\d,\-\s.'’]*\z/
  ENUM_WORDS = {"words" => 1, "letters" => 1, "abbreviation" => 3, "acronym" => 3}
  # A parenthesised group, optionally followed by * (exolve: hide the enum)
  PAREN = /\(([^()]*)\)\*?/

  # :numeric, :other, or nil if s (the text between the parentheses) is not
  # an enumeration
  def self.enumeration_kind(s)
    s = s.strip
    return :numeric if s.match?(NUMERIC_ENUM)
    words = s.downcase.scan(/[[:alpha:]]+/)
    wordy = words.any? do |w|
      ENUM_WORDS.any? {|full, min| w.length >= min && full.start_with?(w)}
    end
    :other if wordy || s.include?("?")
  end

  # The enumeration in a clue, as MatchData for the parenthesised group (with
  # the enumeration in m[1]), or nil. If there are several candidates, the
  # last numeric one is used, so that "Ends (word) here (4)" has the
  # enumeration 4; only if there is no numeric one is the last other kind
  # used.
  def self.find_enumeration(s)
    candidates = s.to_enum(:scan, PAREN).map { Regexp.last_match }
    kinds = candidates.map {|m| enumeration_kind(m[1])}
    numeric = candidates.zip(kinds).select {|_, k| k == :numeric}.map(&:first)
    other = candidates.zip(kinds).select {|_, k| k}.map(&:first)
    (numeric.empty? ? other : numeric).last
  end

  # Text ending in an enumeration -> [text, enumeration], or nil
  def self.split_trailing_enumeration(s)
    m = s.match(/#{PAREN}\s*\z/)
    [m.pre_match.rstrip, m[1].strip] if m && enumeration_kind(m[1])
  end

  def initialize(text = nil, **args)
    @text = text
    LISTS.each {|f| instance_variable_set(:"@#{f}", [])}
    args.each {|k, v| public_send(:"#{k}=", v)}
  end

  # Clue | String | nil -> Clue | nil
  def self.coerce(c)
    c.is_a?(Clue) || c.nil? ? c : new(c.to_s)
  end

  # Split a trailing enumeration off a clue: "Feline (3)" -> text "Feline",
  # enumeration "3"
  def self.parse(s, **args)
    s = s.to_s.strip
    text, enum = split_trailing_enumeration(s)
    if enum
      new(text, enumeration: enum, **args)
    else
      new(s, **args)
    end
  end

  LISTS.each do |f|
    define_method(:"#{f}=") {|v| instance_variable_set(:"@#{f}", v || [])}
  end

  # The clue as plain text, with its enumeration
  def to_s
    s = text.to_s
    s = "See #{parent}" if s.empty? && parent
    enumeration ? "#{s} (#{enumeration})".strip : s
  end

  def ==(other)
    other.is_a?(Clue) && FIELDS.all? {|f| send(f) == other.send(f)}
  end

  def inspect
    fields = FIELDS.map {|f| [f, send(f)]}.reject {|_, v| v.nil? || v == []}
    "#<Clue #{fields.map {|f, v| "#{f}=#{v.inspect}"}.join(' ')}>"
  end
end

end # module Pangrid
