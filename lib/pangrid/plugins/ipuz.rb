# ipuz (http://www.ipuz.org) is an open JSON format for crosswords and other
# puzzles. We support the crossword kind.
#
# Coordinates (clue "cells", zone "cells" and "rect") are [col, row],
# counting from 0 at the top left, as in the examples in the spec.
#
# provides:
#   Ipuz : read, write

require 'json'

module Pangrid

class Ipuz < Plugin

  DESCRIPTION = "ipuz crossword format (http://www.ipuz.org)"
  FEATURES = %i(bars circles colors highlights given labels marks void
                explanations hints linked_clues nodir_clues final_answer
                misses)

  IPUZ_VERSION = "http://ipuz.org/v2"
  IPUZ_KIND = "http://ipuz.org/crossword#1"

  # ipuz field => XWord field
  METADATA = {
    "title" => :title, "author" => :author, "editor" => :editor,
    "copyright" => :copyright, "publisher" => :publisher,
    "publication" => :publication, "url" => :url, "uniqueid" => :id,
    "intro" => :preamble, "notes" => :notes, "explanation" => :explanation,
    "annotation" => :annotation, "date" => :date, "difficulty" => :difficulty,
    "origin" => :origin, "charset" => :charset
  }

  DIRECTIONS = {"Across" => :across, "Down" => :down}
  SIDES = {"T" => :top, "R" => :right, "B" => :bottom, "L" => :left}

  # Clue fields copied as they are
  CLUE_FIELDS = %w(label enumeration explanation answer hints image type tags
                   highlight)

  def read(data)
    # some sites serve ipuz as JSONP, wrapped in ipuz(...)
    data = data.strip.sub(/\Aipuz\((.*)\)\s*;?\z/m, '\1')
    begin
      json = ::JSON.parse(data)
    rescue ::JSON::ParserError => e
      raise PuzzleFormatError, "Invalid JSON: #{e.message}"
    end
    check("Expected a JSON object") { json.is_a?(Hash) }
    check("Not an ipuz file") { json["version"].to_s.start_with?("http://ipuz.org/") }
    kinds = Array(json["kind"])
    check("Only ipuz crosswords are supported") {
      kinds.any? {|k| k.to_s.start_with?("http://ipuz.org/crossword")}
    }
    @block = (json["block"] || "#").to_s
    @empty = (json["empty"] || 0).to_s
    @styles = json["styles"].is_a?(Hash) ? json["styles"] : {}

    xw = XWord.new
    dims = json["dimensions"]
    check("dimensions must give a width and height") {
      dims.is_a?(Hash) && [dims["width"], dims["height"]].all? {|i| i.is_a?(Integer) && i > 0}
    }
    xw.width, xw.height = dims["width"], dims["height"]
    METADATA.each {|k, f| xw[f] = json[k].to_s if json[k]}

    numbers = read_grid(xw, json["puzzle"], json["solution"])
    read_zones(xw, json["zones"])
    read_labels(xw, numbers)
    read_clues(xw, json["clues"])
    read_answers(xw, json)
    xw.misses = json["misses"].transform_values(&:to_s) if json["misses"].is_a?(Hash)
    xw
  end

  def write(xw)
    xw.number
    h = {"version" => IPUZ_VERSION, "kind" => [IPUZ_KIND]}
    METADATA.each {|k, f| h[k] = xw[f] if xw[f]}
    h["dimensions"] = {"width" => xw.width, "height" => xw.height}
    h["puzzle"] = xw.solution.each_with_index.map do |row, y|
      row.each_with_index.map {|cell, x| write_cell(xw, x, y, cell)}
    end
    solution = xw.solution.map {|row| row.map {|cell| write_solution(cell)}}
    if solution.flatten.any? {|s| s.is_a?(String) && s != "#"}
      h["solution"] = solution
    end
    clues = write_clues(xw)
    h["clues"] = clues unless clues.empty?
    h["showenumerations"] = true if xw.all_clues.any?(&:enumeration)
    write_answers(xw, h)
    h["misses"] = xw.misses if xw.misses && !xw.misses.empty?
    format_json(h)
  end

  private

  # Reading

  def block?(v)
    v.to_s == @block
  end

  def empty?(v)
    v.to_s == @empty
  end

  # A number given as a string ("12") is still a number
  def clue_number(v)
    v.is_a?(String) && v =~ /\A\d+\z/ ? v.to_i : v
  end

  # Fills in xw.solution and returns {[x, y] => clue number from the grid}
  def read_grid(xw, puzzle, solution)
    check("puzzle must be a list of #{xw.height} rows of #{xw.width} cells") {
      grid?(xw, puzzle)
    }
    check("solution must be a list of #{xw.height} rows of #{xw.width} cells") {
      solution.nil? || grid?(xw, solution)
    }
    numbers = {}
    xw.solution = puzzle.each_with_index.map do |row, y|
      row.each_with_index.map do |p, x|
        value, style, given = p.is_a?(Hash) ? [p["cell"], p["style"], p["value"]] : [p, nil, nil]
        cell = Cell.new
        if value.nil?
          cell.solution = :void
        elsif block?(value)
          cell.solution = :black
        else
          numbers[[x, y]] = clue_number(value) unless empty?(value)
          cell.solution = solution ? read_solution(solution[y][x]) : :null
          if given.is_a?(String) && !given.empty?
            cell.given = true
            cell.solution = read_letter(given) if cell.solution == :null
          end
        end
        apply_style(xw, x, y, cell, style)
        cell
      end
    end
    numbers
  end

  def grid?(xw, g)
    g.is_a?(Array) && g.length == xw.height &&
      g.all? {|row| row.is_a?(Array) && row.length == xw.width}
  end

  # A CrosswordValue from the solution grid -> Cell#solution
  def read_solution(v)
    v = v["value"] if v.is_a?(Hash)
    v = v.first if v.is_a?(Array)
    if v.nil? || empty?(v)
      :null
    elsif block?(v)
      :black
    else
      read_letter(v.to_s)
    end
  end

  def read_letter(s)
    s.length == 1 ? s : Rebus.new(s)
  end

  def style_spec(style)
    style = @styles[style] if style.is_a?(String)
    style.is_a?(Hash) ? style : {}
  end

  def apply_style(xw, x, y, cell, style)
    s = style_spec(style)
    cell.circle = true if s["shapebg"] == "circle"
    cell.highlight = true if s["highlight"]
    cell.color = s["color"].to_s if s["color"]
    if s["barred"].is_a?(String)
      s["barred"].chars.map {|c| SIDES[c.upcase]}.compact.each {|side| xw.set_bar(x, y, side)}
    end
    if s["mark"].is_a?(Hash)
      cell.marks = cell.marks.merge(s["mark"].transform_values(&:to_s))
    end
  end

  # Zones apply a style to a group of cells
  def read_zones(xw, zones)
    return unless zones.is_a?(Array)
    zones.each do |z|
      next unless z.is_a?(Hash)
      group_cells(xw, z).each {|x, y| apply_style(xw, x, y, xw.solution[y][x], z["style"])}
    end
  end

  def group_cells(xw, g)
    cells = g["cells"].is_a?(Array) ? g["cells"] : []
    if g["rect"].is_a?(Array) && g["rect"].length == 4
      x1, y1, x2, y2 = g["rect"]
      cells += (y1..y2).flat_map {|y| (x1..x2).map {|x| [x, y]}}
    end
    cells.select {|x, y| in_grid?(xw, x, y)}
  end

  def in_grid?(xw, x, y)
    x.is_a?(Integer) && y.is_a?(Integer) &&
      (0...xw.width).cover?(x) && (0...xw.height).cover?(y)
  end

  # ipuz gives every clue number in the grid. Where they differ from the
  # standard numbering, the square gets a label. (If the grid has no numbers
  # at all, use the standard numbering.)
  def read_labels(xw, numbers)
    return if numbers.empty?
    n = 1
    xw.lights.map {|l| [l.x, l.y]}.uniq.each do |x, y|
      given = numbers[[x, y]]
      if given == n
        n += 1
      else
        xw.solution[y][x].label = given.to_s
      end
    end
  end

  def read_clues(xw, clues)
    return unless clues.is_a?(Hash)
    across, down, nodir = [], [], []
    clues.each do |key, list|
      next unless list.is_a?(Array)
      dir = DIRECTIONS[key.to_s.split(":").first]
      parsed = list.map {|c| read_clue(xw, c, dir)}
      case dir
      when :across then across += parsed
      when :down then down += parsed
      else nodir += parsed
      end
    end
    xw.across_clues = place_clues(xw, across, :across)
    xw.down_clues = place_clues(xw, down, :down)
    xw.nodir_clues = nodir
  end

  def read_clue(xw, c, dir)
    case c
    when Array
      Clue.new(c[1].to_s, number: clue_number(c[0]))
    when Hash
      numbers = c["numbers"].is_a?(Array) ? c["numbers"] : [c["number"]].compact
      clue = Clue.new(c["clue"] && c["clue"].to_s)
      clue.number = clue_number(numbers.first)
      clue.linked = numbers.drop(1).map {|n| ClueRef.new(clue_number(n))} +
                    refs(c["continued"])
      clue.references = refs(c["references"])
      clue.cells = group_cells(xw, c)
      CLUE_FIELDS.each {|f| clue.send(:"#{f}=", c[f]) unless c[f].nil?}
      clue.enumeration = clue.enumeration.to_s if clue.enumeration
      clue.hints = Array(clue.hints).map(&:to_s)
      clue.tags = Array(clue.tags).map(&:to_s)
      clue
    else
      Clue.new(c.to_s)
    end
  end

  def refs(list)
    return [] unless list.is_a?(Array)
    list.select {|r| r.is_a?(Hash)}.map do |r|
      ClueRef.new(clue_number(r["number"]), DIRECTIONS[r["direction"].to_s.split(":").first])
    end
  end

  # Match clues to the grid by number. If a clue can't be placed, keep the
  # clues in the order given.
  def place_clues(xw, clues, dir)
    return clues if clues.empty?
    lights = xw.lights.select {|l| l.direction == dir}
    by_number = clues.group_by {|c| c.number.to_s}
    placed = lights.map {|l| (by_number.delete(l.number.to_s) || []).first}
    return clues unless by_number.empty? && clues.length == placed.compact.length
    lights.zip(placed).map {|l, c| c || Clue.new(number: l.number)}
  end

  def read_answers(xw, json)
    answers = Array(json["answers"] || json["answer"])
    enums = Array(json["enumerations"] || json["enumeration"])
    n = [answers.length, enums.length].max
    return if n == 0
    xw.questions = (0...n).map do |i|
      Question.new(nil, enums[i] && enums[i].to_s, answers[i] && answers[i].to_s)
    end
  end

  # Writing

  # Pretty-printed JSON, with each grid row and each clue on a line of its
  # own
  def format_json(h)
    compact = {}
    placeholder = lambda do |rows, indent|
      key = "@@#{compact.length}@@"
      compact[key] = [rows, indent]
      key
    end
    h = h.dup
    %w(puzzle solution).each {|k| h[k] = placeholder.(h[k], 4) if h[k]}
    if h["clues"]
      h["clues"] = h["clues"].transform_values {|list| placeholder.(list, 6)}
    end
    out = ::JSON.pretty_generate(h)
    compact.each do |key, (rows, indent)|
      lines = rows.map {|r| " " * indent + ::JSON.generate(r)}
      out = out.sub("\"#{key}\"") { "[\n" + lines.join(",\n") + "\n" + " " * (indent - 2) + "]" }
    end
    out + "\n"
  end

  def write_cell(xw, x, y, cell)
    return nil if cell.void?
    value =
      if cell.black?
        "#"
      elsif cell.label
        cell.label.empty? ? 0 : clue_number(cell.label)
      else
        cell.number || 0
      end
    style = write_style(xw, x, y, cell)
    given = cell.given && cell.light? && letter(cell)
    return value unless style || given
    h = {"cell" => value}
    h["style"] = style if style
    h["value"] = given if given
    h
  end

  def write_style(xw, x, y, cell)
    s = {}
    s["shapebg"] = "circle" if cell.circle
    s["highlight"] = true if cell.highlight
    s["color"] = cell.color.sub(/\A#(\h{6})\z/, '\1') if cell.color
    # each bar is written once, on the square to its left or above it
    bars = ""
    bars << "R" if xw.bar?(x, y, :right)
    bars << "B" if xw.bar?(x, y, :bottom)
    s["barred"] = bars unless bars.empty?
    s["mark"] = cell.marks unless cell.marks.empty?
    s.empty? ? nil : s
  end

  def letter(cell)
    cell.rebus? ? cell.solution.solution : cell.solution
  end

  def write_solution(cell)
    case cell.solution
    when :void then nil
    when :black then "#"
    when :null then 0
    else letter(cell)
    end
  end

  def write_clues(xw)
    out = {}
    {"Across" => :across, "Down" => :down}.each do |key, dir|
      lights = xw.lights.select {|l| l.direction == dir}
      clues = xw.send(:"#{dir}_clues")
      next if clues.compact.empty?
      out[key] = lights.each_with_index.map {|l, i| write_clue(clues[i] || Clue.new, l.number, dir)}
    end
    unless xw.nodir_clues.empty?
      out["Clues"] = xw.nodir_clues.map {|c| write_clue(c, nil, nil)}
    end
    out
  end

  def write_clue(clue, number, dir)
    text = clue.text.to_s
    if text.empty? && clue.parent
      p = clue.parent
      text = "See #{p.number} #{DIRECTIONS.key(p.direction || dir)}".strip
    end
    h = {}
    h["number"] = number.is_a?(String) && number.empty? ? nil : number
    h["clue"] = text
    CLUE_FIELDS.each do |f|
      v = clue.send(f)
      h[f] = v unless v.nil? || v == []
    end
    h["continued"] = write_refs(clue.linked, dir) unless clue.linked.empty?
    h["references"] = write_refs(clue.references, dir) unless clue.references.empty?
    h["cells"] = clue.cells unless clue.cells.empty?
    h.compact!
    h.keys == %w(number clue) ? [number, text] : h
  end

  def write_refs(refs, dir)
    refs.map do |r|
      {"direction" => DIRECTIONS.key(r.direction || dir) || "Clues", "number" => r.number}
    end
  end

  def write_answers(xw, h)
    finals = (xw.questions || []).reject(&:text)
    return if finals.empty?
    answers = finals.map(&:answer)
    enums = finals.map(&:enumeration)
    if finals.length == 1
      h["answer"] = answers[0] if answers[0]
      h["enumeration"] = enums[0] if enums[0]
    else
      h["answers"] = answers if answers.any?
      h["enumerations"] = enums if enums.any?
    end
  end
end

end # module Pangrid
