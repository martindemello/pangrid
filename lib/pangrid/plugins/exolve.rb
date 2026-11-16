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
  # Written when the puzzle has no id; exolve needs one to save progress
  PLACEHOLDER_ID = 'replace-with-unique-id'

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

  # Light, Clue -> String[]
  #
  # Lights whose square has a label (and so no number) are placed by giving
  # the square's location instead: "#c1r3 [B] Clue"
  def format_clue(xw, light, clue)
    clue ||= Clue.new
    return [] if clue.parent && clue.text.to_s.empty?
    n, label, cells = light && light.number, clue.label, clue.cells
    if n.is_a?(String)
      cells = [[light.x, light.y]]
      label = n unless n.empty?
      n = nil
    end
    lead = cells.map {|c| "#" + format_cell(xw, c)}
    lead << ([n] + clue.linked).compact.map(&:to_s).join(", ") if n
    lead = lead.join(" ")
    lead = lead.rjust(2) if n && cells.empty?
    s = lead.empty? ? [] : [lead]
    s << "[#{label}]" if label
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
    grid = format_grid(xw)
    ac = format_clues(xw, xw.across_clues, :across)
    dn = format_clues(xw, xw.down_clues, :down)
    body = headers +
      section("grid", grid) +
      section("across", ac) +
      section("down", dn)
    unless xw.nodir_clues.empty?
      body += section("nodir", xw.nodir_clues.flat_map {|c| format_clue(xw, nil, c)})
    end
    body += format_colours(xw)
    body += format_extras(xw)
    body += header("explanations", xw.explanation, multiline: true) if xw.explanation
    body += header("postscript", xw.postscript, multiline: true) if xw.postscript
    out = ["exolve-begin"] + indent(body) + ["exolve-end"]
    out.join("\n")
  end

  # Single line headers are written inline, multi-line ones on the following
  # lines
  def header(key, value, multiline: false)
    lines = value.to_s.split("\n")
    if lines.length > 1 || multiline
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
      ['id', xw.id || PLACEHOLDER_ID],
      ['title', xw.title],
      ['setter', xw.author],
      ['width', xw.width],
      ['height', xw.height],
      ['copyright', xw.copyright],
      *(xw.credits || []).map {|c| ['credits', c]},
      ['email', xw.email],
      ['language', xw.language],
      ['maker', xw.origin],
      ['prelude', xw.preamble]
    ]
    headers.select {|k, v| v}.flat_map {|k, v| header(k, v)}
  end

  def format_clues(xw, clues, dir)
    lights = xw.lights.select {|l| l.direction == dir}
    lights.each_with_index.flat_map {|l, i| format_clue(xw, l, clues[i])}
  end

  def format_extras(xw)
    out = (xw.ninas || []).map do |n|
      "exolve-nina: " + ([n.color] + n.cells.map {|c| format_cell(xw, c)}).compact.join(" ")
    end
    out += (xw.questions || []).map do |q|
      # exolve needs an enumeration to check an answer
      enum = q.enumeration || (q.answer && q.answer.split(/\s+/).map(&:length).join(","))
      "exolve-question: " + [q.text, enum && "(#{enum})", q.answer].compact.join(" ")
    end
    out + (xw.alternatives || []).map do |group|
      "exolve-alternatives: " + group.map {|c, l| "#{format_cell(xw, c)}:#{l}"}.join(" ")
    end
  end

  # One exolve-colour line per colour
  def format_colours(xw)
    cells = Hash.new {|h, k| h[k] = []}
    xw.each_cell_with_coords {|x, y, c| cells[c.color] << [x, y] if c.color}
    cells.map do |colour, cs|
      "exolve-colour: #{colour} " + cs.map {|c| format_cell(xw, c)}.join(" ")
    end
  end

  def indent(lines)
    lines.map {|x| "  " + x}
  end

  # Exolve marks squares with decorators after the letter:
  #   | bar on the right, _ bar underneath, + both
  #   @ circle, * diagramless, ! letter given, ~ no clue number
  # If any square has decorators, squares are padded so the columns line up.
  def format_grid(xw)
    rows = xw.to_array(:black => '.', :null => '0') {|c| grid_char(c)}
    tokens = rows.each_with_index.map do |row, y|
      row.each_with_index.map {|ch, x| ch.to_s + decorators(xw, x, y)}
    end
    width = tokens.flatten.map(&:length).max
    tokens.map {|row| row.map {|t| t.ljust(width)}.join.rstrip}
  end

  def decorators(xw, x, y)
    cell = xw.solution[y][x]
    right, bottom = xw.bar?(x, y, :right), xw.bar?(x, y, :bottom)
    d = right && bottom ? '+' : right ? '|' : bottom ? '_' : ''
    d += '@' if cell.circle
    d += '*' if cell.diagramless
    d += '!' if cell.given
    d += '~' if cell.label
    d
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
    colours, ninas = [], []
    sections(lines).each do |field, value, body|
      text = value.empty? ? body.map(&:strip).join("\n") : value
      next if field == "id" && text == PLACEHOLDER_ID
      if %w(id title copyright email language postscript).include? field
        xw[field] = text
      elsif field == "explanations"
        xw.explanation = text
      elsif field == "credits"
        (xw.credits ||= []) << text
      elsif field == "maker"
        xw.origin = text
      elsif %w(prelude preamble).include? field
        xw.preamble = text
      elsif field == "setter"
        xw.author = text
      elsif %w(height width).include? field
        xw[field] = text.to_i
      elsif %w(across down nodir).include? field
        clues[field] = body
      elsif %w(colour color).include? field
        colours << text
      elsif field == "nina"
        ninas << text
      elsif field == "question"
        (xw.questions ||= []) << parse_question(text)
      elsif field == "alternatives"
        (xw.alternatives ||= []) << parse_alternatives(xw, text)
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
    xw.mirror_bars!
    read_clues(xw, clues)
    colours.each do |line|
      colour, cells = parse_cell_list(xw, line)
      cells.each {|x, y| xw.solution[y][x].color = colour} if colour
    end
    xw.ninas = ninas.map {|line| Nina.new(*parse_cell_list(xw, line).reverse)} unless ninas.empty?
    xw
  end

  # "What links the ninas? (3,4) GET LOST"
  def parse_question(s)
    m = s.to_enum(:scan, ENUM).map { Regexp.last_match }.last
    return Question.new(s.strip) unless m
    answer = m.post_match.strip
    Question.new(m.pre_match.strip, m[1].strip, answer.empty? ? nil : answer)
  end

  # "r1c6:Z r2c1:A" -> {[5, 2] => "Z", [0, 1] => "A"}
  def parse_alternatives(xw, s)
    s.split.each_with_object({}) do |word, h|
      loc, letter = word.split(":", 2)
      cell = parse_cell(xw.height, loc)
      h[cell] = letter if cell && letter
    end
  end

  # "palegreen a1 c2r3 A12 16D" -> ["palegreen", [[x, y], ...]], where A12
  # and 16D are all the squares of 12 across and 16 down. The colour (or
  # other non-location word) can be anywhere in the list.
  def parse_cell_list(xw, line)
    other = nil
    cells = line.split.flat_map do |word|
      if (cell = parse_cell(xw.height, word))
        x, y = cell
        (0...xw.width).cover?(x) && (0...xw.height).cover?(y) ? [cell] : []
      elsif (m = word.match(/\A(?:([AD])(\d+)|(\d+)([adAD]))\z/))
        dir = (m[1] || m[4]).downcase == "a" ? :across : :down
        light = xw.light((m[2] || m[3]).to_i, dir)
        light ? xw.light_cells(light.x, light.y, dir) : []
      else
        other = word
        []
      end
    end
    [other, cells]
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
    children = linked_children(across, :across).merge(linked_children(down, :down))
    xw.across_clues = align_clues(xw, across, :across, children)
    xw.down_clues = align_clues(xw, down, :down, children)
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

  # Match clues to the grid, by number or by the location of their first
  # square ("#c1r3 [B] Clue", used for squares marked ~ with no number), and
  # fill in the later parts of linked clues, which exolve does not require to
  # be listed. If a clue can't be placed, keep the clues in the order given.
  def align_clues(xw, clues, dir, children)
    return clues if clues.empty?
    lights = xw.lights.select {|l| l.direction == dir}
    placed = {}
    clues.each do |c|
      light =
        if c.cells.length == 1
          lights.find {|l| [l.x, l.y] == c.cells[0]}
        elsif c.number
          lights.find {|l| l.number == c.number}
        end
      return clues if light.nil? || placed[light]
      placed[light] = c
    end
    lights.map do |l|
      c = placed[l] || Clue.new(number: l.number, parent: children[[l.number, dir]])
      cell = xw.solution[l.y][l.x]
      if c.cells == [[l.x, l.y]]
        # the location just places the clue; a label belongs to the square
        c.cells = []
        cell.label = (c.label || c.number).to_s if cell.label == ""
        c.label = nil
      end
      c
    end
  end

  def parse_grid_char(char)
    case char
    when '0'; :null
    when '.'; :black
    else; char
    end
  end

  # Each square is a character followed by optional decorators (see
  # ExolveWriter#format_grid)
  def parse_grid(lines)
    grid = lines.map do |line|
      line.scan(/([^\s|_+@*!~])([|_+@*!~]*)/).map do |c, decorators|
        cell = Cell.new(:solution => parse_grid_char(c))
        cell.borders << :right if decorators =~ /[|+]/
        cell.borders << :bottom if decorators =~ /[_+]/
        cell.circle = true if decorators.include?("@")
        cell.diagramless = true if decorators.include?("*")
        cell.given = true if decorators.include?("!")
        cell.label = "" if decorators.include?("~")
        cell
      end
    end
    grid
  end
end

EXOLVE_FEATURES = %i(bars circles colors given diagramless labels
                     explanations hints linked_clues nodir_clues
                     ninas questions final_answer alternatives)

class ExolveFilled < Plugin
  include ExolveReader
  include ExolveWriter

  DESCRIPTION = "Exolve writer with solutions"
  FEATURES = EXOLVE_FEATURES

  def grid_char(cell)
    cell.to_char
  end
end

class ExolveBlank < Plugin
  include ExolveWriter

  DESCRIPTION = "Exolve writer without solutions"
  FEATURES = EXOLVE_FEATURES

  # given letters are shown even in a blank grid
  def grid_char(cell)
    cell.given ? cell.to_char : '0'
  end
end

end # module Pangrid
