# Exolve (https://github.com/viresh-ratnakar/exolve) is a browser-based
# crossword solver that allows you to embed the crossword and solving software
# in a single HTML file.

module Pangrid

# Clue syntax shared by the reader and writer:
#
#   1, 5, 2d Clue text (7,3,4) Explanation
#   Hint: a hint
#   Concise: a shorter clue
#
# Linked clues list the later parts after the first number; parts in another
# direction get a suffix (a or d). The explanation ("anno") follows the
# enumeration; a clue with an explanation but no enumeration separates the two
# with "[]". Clues without a direction (exolve-nodir) start with the cells
# they occupy and a label: "#c3 #c5 [A] Clue (2)".
module ExolveClues
  DIRECTION_SUFFIX = {"a" => :across, "d" => :down}
  REF = /\d+[adbu]?/
  LEAD = /\A(#{REF}(?:\s*[,&]\s*#{REF})*)\.?(?:\s+|\z)/
  CELL = /#([a-z]\d+|c\d+r\d+|r\d+c\d+)\s+/
  LABEL = /\A\[([^\]]+)\]\s*/
  ENUM = /\((\d[\d,\-\s.'’]*)\)\*?/

  # [x, y] -> "c<col>r<row>", rows counted from the bottom
  def format_cell(xw, (x, y))
    "c#{x + 1}r#{xw.height - y}"
  end

  def parse_cell(height, s)
    case s
    when /\A([a-z])(\d+)\z/ then [$1.ord - 'a'.ord, height - $2.to_i]
    when /\Ac(\d+)r(\d+)\z/ then [$1.to_i - 1, height - $2.to_i]
    when /\Ar(\d+)c(\d+)\z/ then [$2.to_i - 1, height - $1.to_i]
    end
  end

  def parse_ref(s)
    ClueRef.new(s.to_i, DIRECTION_SUFFIX[s[/[a-z]\z/]])
  end

  # String -> Clue
  def parse_clue(line, height)
    clue = Clue.new
    s = line.strip
    while (m = s.match(/\A#{CELL}/))
      clue.cells << parse_cell(height, m[1])
      s = m.post_match
    end
    if (m = s.match(LEAD))
      first, *rest = m[1].split(/\s*[,&]\s*/)
      clue.number = first.to_i
      clue.linked = rest.map {|r| parse_ref(r)}
      s = m.post_match
    end
    if (m = s.match(LABEL))
      clue.label = m[1]
      s = m.post_match
    end
    if s.include?("[]")
      text, anno = s.split("[]", 2)
      m = text.match(/\A(.*?)\s*#{ENUM}\s*\z/m)
      text, enum = m ? [m[1], m[2]] : [text, nil]
    elsif (m = s.to_enum(:scan, ENUM).map { Regexp.last_match }.last)
      text, enum, anno = m.pre_match, m[1], m.post_match
    else
      text, enum, anno = s, nil, nil
    end
    clue.text = text.strip
    clue.enumeration = enum && enum.strip
    clue.explanation = anno.strip if anno && !anno.strip.empty?
    clue
  end

  # String[] -> Clue[], attaching Hint: and Concise: lines to their clues
  def parse_clues(lines, height)
    clues = []
    lines.each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("---")
      if (m = line.match(/\Ahint:\s*/i)) && clues.last
        clues.last.hints << m.post_match
      elsif (m = line.match(/\Aconcise:\s*/i)) && clues.last
        clues.last.concise = m.post_match
      else
        clues << parse_clue(line, height)
      end
    end
    clues
  end

  # Clue -> String[]
  def format_clue(xw, n, clue, dir)
    clue ||= Clue.new
    return [] if clue.parent && clue.text.to_s.empty?
    lead = clue.cells.map {|c| "#" + format_cell(xw, c)}
    lead << ([n] + clue.linked).compact.map(&:to_s).join(", ") if n
    lead = lead.join(" ")
    lead = lead.rjust(2) if n && clue.cells.empty?
    s = [lead]
    s << "[#{clue.label}]" if clue.label
    s << clue.text if clue.text && !clue.text.empty?
    s << "(#{clue.enumeration})" if clue.enumeration
    if clue.explanation
      s << "[]" unless clue.enumeration
      s << clue.explanation
    end
    [s.join(" ").rstrip] +
      clue.hints.map {|h| "Hint: #{h}"} +
      (clue.concise ? ["Concise: #{clue.concise}"] : [])
  end
end

module ExolveWriter
  include ExolveClues

  def write(xw)
    headers = format_headers(xw)
    across, down = xw.number
    grid = format_grid(xw)
    ac = format_clues(xw, across, xw.across_clues, :across)
    dn = format_clues(xw, down, xw.down_clues, :down)
    body = headers +
      section("grid", grid) +
      section("across", ac) +
      section("down", dn)
    unless xw.nodir_clues.empty?
      body += section("nodir", xw.nodir_clues.flat_map {|c| format_clue(xw, nil, c, nil)})
    end
    out = ["exolve-begin"] + indent(body) + ["exolve-end"]
    out.join("\n")
  end

  # Single line headers are written inline, multi-line ones on the following
  # lines
  def header(key, value)
    lines = value.to_s.split("\n")
    if lines.length > 1
      section(key, lines)
    else
      ["exolve-#{key}: #{value}"]
    end
  end

  def section(key, lines)
    ["exolve-#{key}:"] + indent(lines)
  end

  def format_headers(xw)
    headers = [
      'id', 'replace-with-unique-id',
      'title', xw.title,
      'setter', xw.author,
      'width', xw.width,
      'height', xw.height,
      'copyright', xw.copyright,
      'prelude', xw.preamble
    ]
    headers.each_slice(2).select {|k, v| v}.flat_map {|k, v| header(k, v)}
  end

  def format_clues(xw, numbers, clues, dir)
    numbers.each_with_index.flat_map {|n, i| format_clue(xw, n, clues[i], dir)}
  end

  def indent(lines)
    lines.map {|x| "  " + x}
  end

  # Exolve marks bars with decorators after a square: | for a bar on the
  # right, _ for a bar underneath and + for both. If the grid has any bars,
  # squares are separated by spaces so that the columns line up.
  def format_grid(xw)
    rows = xw.to_array(:black => '.', :null => '0') {|c| grid_char(c)}
    decorators = rows.each_index.map do |y|
      rows[y].each_index.map do |x|
        right, bottom = xw.bar?(x, y, :right), xw.bar?(x, y, :bottom)
        right && bottom ? '+' : right ? '|' : bottom ? '_' : ' '
      end
    end
    if decorators.flatten.all? {|d| d == ' '}
      rows.map(&:join)
    else
      rows.zip(decorators).map {|r, d| r.zip(d).join.rstrip}
    end
  end
end

module ExolveReader
  include ExolveClues

  def read(data)
    s = data.each_line.map(&:rstrip)
    first = s.index('exolve-begin')
    check("exolve-begin missing") { first }
    last = s.index('exolve-end')
    check("exolve-end missing") { last }
    lines = s[(first + 1)...last]
    xw = XWord.new
    clues = {}
    sections(lines).each do |field, value, body|
      text = value.empty? ? body.map(&:strip).join("\n") : value
      if %w(title copyright).include? field
        xw[field] = text
      elsif %w(prelude preamble).include? field
        xw.preamble = text
      elsif field == "setter"
        xw.author = text
      elsif %w(height width).include? field
        xw[field] = text.to_i
      elsif %w(across down nodir).include? field
        clues[field] = body
      elsif field == "grid"
        xw.solution = parse_grid(body)
      end
    end
    check("exolve-grid missing") { xw.solution && !xw.solution.empty? }
    xw.height ||= xw.solution.length
    xw.width ||= xw.solution[0].length
    check("Grid does not match exolve-width/exolve-height " +
          "(#{xw.width}x#{xw.height})") {
      xw.solution.length == xw.height &&
        xw.solution.all? {|row| row.length == xw.width}
    }
    read_clues(xw, clues)
    xw
  end

  # Lines -> [field, inline value, following lines][]
  def sections(lines)
    headers = lines.each.with_index.map do |l, i|
      m = l.match(/^(\s+)exolve-([\w-]+):(.*)$/)
      m && [i, m[2], m[3].strip]
    end
    headers.compact!
    headers.push([lines.length])
    headers.each_cons(2).map do |(i, field, value), (j, _)|
      [field, value, lines[(i + 1)...j]]
    end
  end

  def read_clues(xw, sections)
    h = xw.height
    across = parse_clues(sections["across"] || [], h)
    down = parse_clues(sections["down"] || [], h)
    xw.nodir_clues = parse_clues(sections["nodir"] || [], h)
    a, d = xw.number
    children = linked_children(across, :across).merge(linked_children(down, :down))
    xw.across_clues = align_clues(across, a, :across, children)
    xw.down_clues = align_clues(down, d, :down, children)
  end

  # {[number, direction] => ClueRef to the first part} for the later parts
  # of linked clues
  def linked_children(clues, dir)
    clues.each_with_object({}) do |c, h|
      c.linked.each do |r|
        h[[r.number, r.direction || dir]] = ClueRef.new(c.number, dir)
      end
    end
  end

  # Match clues to the grid by number, filling in the later parts of linked
  # clues, which exolve does not require to be listed. If the clue numbers
  # don't match the grid, keep the clues in the order given.
  def align_clues(clues, numbers, dir, children)
    by_number = clues.select(&:number).to_h {|c| [c.number, c]}
    return clues if clues.empty? || by_number.length < clues.length ||
                    !(by_number.keys - numbers).empty?
    numbers.map do |n|
      by_number[n] || Clue.new(number: n, parent: children[[n, dir]])
    end
  end

  def parse_grid_char(char)
    case char
    when '0'; :null
    when '.'; :black
    else; char
    end
  end

  # Each square is a character followed by optional decorators:
  #   | bar after, _ bar under, + both, @ circle, * diagramless
  # Circles and diagramless squares are not supported and are ignored.
  def parse_grid(lines)
    grid = lines.map do |line|
      line.scan(/([^\s|_+@*])([|_+@*]*)/).map do |c, decorators|
        cell = Cell.new(:solution => parse_grid_char(c))
        cell.borders << :right if decorators =~ /[|+]/
        cell.borders << :bottom if decorators =~ /[_+]/
        cell
      end
    end
    mirror_bars(grid)
    grid
  end

  # Record each bar on the squares on both sides of it
  def mirror_bars(grid)
    grid.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        right = row[x + 1]
        below = grid[y + 1] && grid[y + 1][x]
        right.borders |= [:left] if right && cell.has_bar?(:right)
        below.borders |= [:top] if below && cell.has_bar?(:bottom)
      end
    end
  end
end

class ExolveFilled < Plugin
  include ExolveReader
  include ExolveWriter

  DESCRIPTION = "Exolve writer with solutions"
  FEATURES = [:bars, :explanations, :hints, :linked_clues, :nodir_clues]

  def grid_char(cell)
    cell.to_char
  end
end

class ExolveBlank < Plugin
  include ExolveWriter

  DESCRIPTION = "Exolve writer without solutions"
  FEATURES = [:bars, :explanations, :hints, :linked_clues, :nodir_clues]

  def grid_char(cell)
    '0'
  end
end

end # module Pangrid
