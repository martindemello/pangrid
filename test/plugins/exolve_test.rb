require_relative '../test_helper'

class ExolveTest < PangridTest
  def test_write_filled
    out = ExolveFilled.new.write(make_xw(preamble: "Hello"))
    assert_equal <<~EOF.chomp, out
      exolve-begin
        exolve-id: replace-with-unique-id
        exolve-title: Title
        exolve-setter: Author
        exolve-width: 3
        exolve-height: 3
        exolve-copyright: Copyright
        exolve-prelude: Hello
        exolve-grid:
          CAT
          A.O
          BEE
        exolve-across:
           1 Feline
           3 Bee sound
        exolve-down:
           1 Taxi
           2 Foot digit
      exolve-end
    EOF
  end

  def test_write_blank
    out = ExolveBlank.new.write(make_xw)
    assert_includes out, "  exolve-grid:\n    000\n    0.0\n    000\n"
    refute_includes out, "CAT"
  end

  #   A B|C
  #   -
  #   D E F
  def barred_xw
    xw = make_xw(grid: %w(ABC DEF), across: %w(a1 a4), down: %w(d2 d3))
    xw.solution[0][1].borders = [:right]
    xw.solution[0][2].borders = [:left]
    xw.solution[0][0].borders = [:bottom]
    xw.solution[1][0].borders = [:top]
    xw
  end

  def test_write_bars
    out = ExolveFilled.new.write(barred_xw)
    assert_includes out, "  exolve-grid:\n    A_B|C\n    D E F\n"
    assert_includes out, "  exolve-across:\n     1 a1\n     4 a4\n"
    assert_includes out, "  exolve-down:\n     2 d2\n     3 d3\n"
  end

  def test_write_bar_after_and_under
    xw = make_xw(grid: %w(AB CD))
    xw.solution[0][0].borders = [:right, :bottom]
    assert_includes ExolveBlank.new.write(xw), "  exolve-grid:\n    0+0\n    0 0\n"
  end

  def test_write_bar_recorded_on_one_side_only
    xw = make_xw(grid: %w(AB))
    xw.solution[0][1].borders = [:left]
    assert_includes ExolveFilled.new.write(xw), "    A|B\n"
  end

  def test_read_bars
    text = "exolve-begin\n  exolve-grid:\n    A_ B| C\n    D  E  F\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal %w(ABC DEF), grid_strings(xw)
    assert_equal [[:bottom], [:right], [:left]], xw.solution[0].map(&:borders)
    assert_equal [[:top], [], []], xw.solution[1].map(&:borders)
    assert_equal [[1, 4], [2, 3]], xw.number
  end

  def test_read_plus_and_ignored_decorators
    text = "exolve-begin\n  exolve-grid:\n    A+ @B*\n    C  D\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal %w(AB CD), grid_strings(xw)
    assert_equal [:right, :bottom], xw.solution[0][0].borders
    assert_equal [:left], xw.solution[0][1].borders
    assert_equal [:top], xw.solution[1][0].borders
  end

  def test_roundtrip_bars
    w = ExolveFilled.new
    out = w.write(barred_xw)
    assert_equal out, w.write(w.read(out))
  end

  def test_write_omits_missing_headers
    xw = make_xw
    xw.copyright = nil
    refute_includes ExolveBlank.new.write(xw), "copyright"
  end

  def test_read
    xw = ExolveFilled.new.read(ExolveFilled.new.write(make_xw(preamble: "Hi")))
    assert_equal 3, xw.width
    assert_equal 3, xw.height
    assert_equal "Title", xw.title
    assert_equal "Hi", xw.preamble
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues.map(&:to_s)
  end

  def test_read_ignores_unknown_sections
    # "own" used to match as a substring of "across down"
    text = "exolve-begin\n  exolve-own:\n    x\n  exolve-grid:\n    AB\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal [], xw.across_clues.map(&:to_s)
    assert_equal [], xw.down_clues.map(&:to_s)
  end

  def test_read_null_cells
    text = "exolve-begin\n  exolve-grid:\n    A0\n    .B\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal %w(A. #B), grid_strings(xw)
  end

  def test_roundtrip_preserves_clues_and_author
    xw = ExolveFilled.new.read(ExolveFilled.new.write(make_xw))
    assert_equal ACROSS, xw.across_clues.map(&:to_s)
    assert_equal DOWN, xw.down_clues.map(&:to_s)
    assert_equal "Author", xw.author
  end

  def test_read_clue_numbers_with_dots
    text = "exolve-begin\n  exolve-grid:\n    AB\n    CD\n  exolve-across:\n    1. One (2)\n    3 Three (2)\nexolve-end\n"
    assert_equal ["One (2)", "Three (2)"], ExolveFilled.new.read(text).across_clues.map(&:to_s)
  end

  def test_read_without_dimensions
    text = "exolve-begin\n  exolve-grid:\n    ABC\n    D.E\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal [3, 2], [xw.width, xw.height]
  end

  def read_exolve(body, grid: %w(ABC DEF))
    text = "exolve-begin\n  exolve-grid:\n" + grid.map {|r| "    #{r}\n"}.join +
           body.gsub(/^/, "  ") + "exolve-end\n"
    ExolveFilled.new.read(text)
  end

  def test_read_clue_parts
    xw = read_exolve(<<~EOF)
      exolve-across:
        1 Clue with (parens) (3) Anno (here)
        Hint: first
        hint: second
        Concise: Short (3)
        4 No enum [] Just an anno
      exolve-down:
        1 Hidden enum (2)* x
        2 Plain
        3 Last (2,1) wins (2)
    EOF
    c = xw.across_clues[0]
    assert_equal 1, c.number
    assert_equal "Clue with (parens)", c.text
    assert_equal "3", c.enumeration
    assert_equal "Anno (here)", c.explanation
    assert_equal ["first", "second"], c.hints
    assert_equal "Short (3)", c.concise
    c = xw.across_clues[1]
    assert_equal ["No enum", nil, "Just an anno"], [c.text, c.enumeration, c.explanation]
    assert_equal ["Hidden enum", "2", "x"], xw.down_clues[0].then {|d| [d.text, d.enumeration, d.explanation]}
    assert_equal ["Plain", nil, nil], xw.down_clues[1].then {|d| [d.text, d.enumeration, d.explanation]}
    assert_equal ["Last (2,1) wins", "2"], xw.down_clues[2].then {|d| [d.text, d.enumeration]}
  end

  # The examples from the exolve README
  def test_read_enumeration_rules
    xw = read_exolve(<<~EOF, grid: %w(ABCD EFGH IJKL MNOP))
      exolve-across:
        1 This (13) clue ends (word) here! (4)
        5 This (13) clue also ends (1 word) here! (4) Some annotation follows.
        6 This (13) clue also ends (words) here! (8) [] [t]WITTER The anno has (3) enum-like parts.
        7 This clue, even though its anno contains an enum-like substring, ends here! (4) The (word) and (4 letters) enum-like parts here are not numeric.
      exolve-down:
        1 Two words (8, 2 words) anno
        2 Spelt out (two words)
        3 Short (7, 2w)
        4 Odd (?)
    EOF
    a = xw.across_clues
    assert_equal ["This (13) clue ends (word) here!", "4", nil],
                 [a[0].text, a[0].enumeration, a[0].explanation]
    assert_equal ["This (13) clue also ends (1 word) here!", "4", "Some annotation follows."],
                 [a[1].text, a[1].enumeration, a[1].explanation]
    assert_equal ["This (13) clue also ends (words) here!", "8",
                  "[t]WITTER The anno has (3) enum-like parts."],
                 [a[2].text, a[2].enumeration, a[2].explanation]
    assert_equal ["This clue, even though its anno contains an enum-like substring, ends here!", "4"],
                 [a[3].text, a[3].enumeration]
    d = xw.down_clues
    assert_equal ["Two words", "8, 2 words", "anno"], [d[0].text, d[0].enumeration, d[0].explanation]
    assert_equal ["Spelt out", "two words"], [d[1].text, d[1].enumeration]
    assert_equal ["Short", "7, 2w"], [d[2].text, d[2].enumeration]
    assert_equal ["Odd", "?"], [d[3].text, d[3].enumeration]
    assert_includes ExolveFilled.new.write(xw), "     1 Two words (8, 2 words) anno\n"
  end

  def test_read_question_with_word_count
    xw = read_exolve("exolve-question: What is it? (8, 2 words) GET LOST\n")
    assert_equal Question.new("What is it?", "8, 2 words", "GET LOST"), xw.questions[0]
  end

  def test_read_aligns_clues_by_number
    xw = read_exolve(<<~EOF)
      exolve-across:
        4 Second
        1 First
      exolve-down:
        3 Third
    EOF
    assert_equal %w(First Second), xw.across_clues.map(&:to_s)
    assert_equal [1, 2, 3], xw.down_clues.map(&:number)
    assert_equal ["", "", "Third"], xw.down_clues.map(&:to_s)
  end

  def test_read_linked_clues
    xw = read_exolve(<<~EOF)
      exolve-across:
        1, 4, 2d Linked (3,3,2)
      exolve-down:
        1 Down one
        3 & 2 Other
    EOF
    a1, a4 = xw.across_clues
    assert_equal [ClueRef.new(4), ClueRef.new(2, :down)], a1.linked
    assert_equal ClueRef.new(1, :across), a4.parent
    assert_equal "See 1a", a4.to_s
    d1, d2, d3 = xw.down_clues
    assert_equal "Down one", d1.text
    # 2d is claimed by both 1a and 3d; the later one wins
    assert_equal ClueRef.new(3, :down), d2.parent
    assert_equal [ClueRef.new(2)], d3.linked
  end

  def test_read_clues_out_of_step_with_grid
    xw = read_exolve("exolve-across:\n  9 Not in grid\n  Unnumbered\n")
    assert_equal ["Not in grid", "Unnumbered"], xw.across_clues.map(&:to_s)
  end

  def test_read_nodir_clues
    xw = read_exolve(<<~EOF)
      exolve-nodir: Heading
        #a2 #c1r2 #r1c3 [A] Labelled (3)
        [B] No cells
        ---
    EOF
    a, b = xw.nodir_clues
    assert_equal [[0, 0], [0, 0], [2, 1]], a.cells
    assert_equal ["A", "Labelled", "3"], [a.label, a.text, a.enumeration]
    assert_equal [[], "B", nil], [b.cells, b.label, b.number]
    assert_equal 2, xw.nodir_clues.length
  end

  def test_write_clue_parts
    xw = make_xw
    a1, a3 = xw.across_clues
    a1.enumeration = "3"
    a1.explanation = "CAT"
    a1.hints = ["Pet"]
    a1.concise = "Pet (3)"
    a3.explanation = "BEE"
    xw.down_clues[0].linked = [ClueRef.new(3, :across)]
    xw.across_clues[1] = Clue.new(parent: ClueRef.new(1, :down))
    xw.nodir_clues = [Clue.new("Extra", label: "X", cells: [[0, 0], [2, 2]], enumeration: "2")]
    out = ExolveFilled.new.write(xw)
    assert_includes out, <<~EOF.gsub(/^/, "  ")
      exolve-across:
         1 Feline (3) CAT
        Hint: Pet
        Concise: Pet (3)
      exolve-down:
        1, 3a Taxi
         2 Foot digit
      exolve-nodir:
        #c1r3 #c3r1 [X] Extra (2)
    EOF
    assert_includes ExolveFilled.new.write(make_xw.tap {|x| x.across_clues[1].explanation = "anno"}),
                    "     3 Bee sound [] anno\n"
  end

  def test_roundtrip_rich_clues
    xw = make_xw
    xw.across_clues[0] = Clue.new("Feline", number: 1, enumeration: "3",
                                  explanation: "anno", hints: ["h"], concise: "c")
    xw.down_clues[0].linked = [ClueRef.new(2)]
    xw.down_clues[1] = Clue.new(parent: ClueRef.new(1, :down))
    xw.nodir_clues = [Clue.new("N", label: "L", cells: [[1, 0]])]
    w = ExolveFilled.new
    out = w.write(xw)
    read = w.read(out)
    assert_equal out, w.write(read)
    assert_equal xw.across_clues[0], read.across_clues[0]
    assert_equal ClueRef.new(1, :down), read.down_clues[1].parent
    assert_equal [[1, 0]], read.nodir_clues[0].cells
  end

  def test_multiline_prelude
    w = ExolveFilled.new
    out = w.write(make_xw(preamble: "Line 1\nLine 2"))
    assert_includes out, "  exolve-prelude:\n    Line 1\n    Line 2\n"
    assert_equal "Line 1\nLine 2", w.read(out).preamble
  end

  def test_metadata
    xw = make_xw(id: "xw-1", credits: ["Tester: A", "Editor: B"], email: "a@example.com",
                 language: "hi Devanagari", origin: "pangrid",
                 explanation: "Ninas everywhere", postscript: "PS 1\nPS 2")
    w = ExolveFilled.new
    out = w.write(xw)
    assert_includes out, "  exolve-id: xw-1\n"
    assert_includes out, "  exolve-credits: Tester: A\n  exolve-credits: Editor: B\n"
    assert_includes out, "  exolve-email: a@example.com\n"
    assert_includes out, "  exolve-language: hi Devanagari\n"
    assert_includes out, "  exolve-maker: pangrid\n"
    assert_includes out, "  exolve-explanations:\n    Ninas everywhere\n"
    assert_includes out, "  exolve-postscript:\n    PS 1\n    PS 2\n"
    read = w.read(out)
    %i(id credits email language origin explanation postscript).each do |f|
      assert_equal xw[f], read[f], f
    end
  end

  def test_placeholder_id_is_not_read
    w = ExolveFilled.new
    out = w.write(make_xw)
    assert_includes out, "exolve-id: replace-with-unique-id"
    assert_nil w.read(out).id
  end

  def test_cell_decorators
    xw = make_xw
    xw.solution[0][0].circle = true
    xw.solution[0][1].diagramless = true
    xw.solution[0][2].given = true
    xw.solution[2][0].borders = [:right]
    xw.solution[2][1].borders = [:left]
    w = ExolveFilled.new
    out = w.write(xw)
    assert_includes out, "  exolve-grid:\n    C@A*T!\n    A . O\n    B|E E\n"
    read = w.read(out)
    assert read.solution[0][0].circle
    assert read.solution[0][1].diagramless
    assert read.solution[0][2].given
    assert_equal %w(CAT A#O BEE), grid_strings(read)
    assert_equal out, w.write(read)
  end

  def test_blank_grid_shows_given_letters
    xw = make_xw
    xw.solution[0][2].given = true
    assert_includes ExolveBlank.new.write(xw), "  exolve-grid:\n    0 0 T!\n"
  end

  def test_labelled_squares
    xw = make_xw
    xw.solution[0][2].label = "X"
    xw.solution[2][0].label = ""
    w = ExolveFilled.new
    out = w.write(xw)
    assert_includes out, "  exolve-grid:\n    C A T~\n    A . O\n    B~E E\n"
    assert_includes out, "  exolve-across:\n     1 Feline\n    #c1r1 Bee sound\n"
    assert_includes out, "  exolve-down:\n     1 Taxi\n    #c3r3 [X] Foot digit\n"
    read = w.read(out)
    assert_equal "X", read.solution[0][2].label
    assert_equal "", read.solution[2][0].label
    assert_equal ["Feline", "Bee sound"], read.across_clues.map(&:to_s)
    assert_equal ["Taxi", "Foot digit"], read.down_clues.map(&:to_s)
    assert_equal [], read.down_clues[1].cells
    assert_nil read.down_clues[1].label
    assert_equal out, w.write(read)
  end

  def test_colours
    xw = make_xw
    xw.solution[0][0].color = "palegreen"
    xw.solution[2][2].color = "palegreen"
    xw.solution[1][2].color = "#ff0000"
    w = ExolveFilled.new
    out = w.write(xw)
    assert_includes out, "  exolve-colour: palegreen c1r3 c3r1\n"
    assert_includes out, "  exolve-colour: #ff0000 c3r2\n"
    read = w.read(out)
    assert_equal "palegreen", read.solution[2][2].color
    assert_equal "#ff0000", read.solution[1][2].color
    assert_nil read.solution[0][1].color
  end

  def test_read_colour_by_clue
    xw = read_exolve("exolve-color: a3 blue A3 2D x9\n", grid: %w(CAT A.O BEE))
    colours = xw.solution.map {|row| row.map {|c| c.color ? "b" : "-"}.join}
    assert_equal %w(b-b --b bbb), colours
  end

  def test_extras
    xw = make_xw
    xw.ninas = [Nina.new([[0, 0], [2, 2]], "red"), Nina.new([[1, 0]], nil)]
    xw.questions = [Question.new("What links them? [lowercase-ok]", "3,4", "GET LOST"),
                    Question.new("Theme?", nil, "CATS"),
                    Question.new("Any comments?", nil, nil)]
    xw.alternatives = [{[0, 0] => "Z", [1, 0] => "Y"}]
    w = ExolveFilled.new
    out = w.write(xw)
    assert_includes out, "  exolve-nina: red c1r3 c3r1\n  exolve-nina: c2r3\n"
    assert_includes out, "  exolve-question: What links them? [lowercase-ok] (3,4) GET LOST\n"
    assert_includes out, "  exolve-question: Theme? (4) CATS\n"
    assert_includes out, "  exolve-question: Any comments?\n"
    assert_includes out, "  exolve-alternatives: c1r3:Z c2r3:Y\n"
    read = w.read(out)
    assert_equal xw.ninas, read.ninas
    assert_equal xw.questions[0], read.questions[0]
    assert_equal Question.new("Theme?", "4", "CATS"), read.questions[1]
    assert_equal xw.questions[2], read.questions[2]
    assert_equal xw.alternatives, read.alternatives
    assert_equal out, w.write(read)
  end

  def test_read_nina_by_clue
    xw = read_exolve("exolve-nina: A1\n")
    assert_equal [Nina.new([[0, 0], [1, 0], [2, 0]], nil)], xw.ninas
  end

  def test_read_errors
    assert_raises(PuzzleFormatError) { ExolveFilled.new.read("exolve-end\n") }
    assert_raises(PuzzleFormatError) { ExolveFilled.new.read("exolve-begin\n") }
    e = assert_raises(PuzzleFormatError) {
      ExolveFilled.new.read("exolve-begin\n  exolve-title: x\nexolve-end\n")
    }
    assert_match(/grid missing/, e.message)
    e = assert_raises(PuzzleFormatError) {
      ExolveFilled.new.read("exolve-begin\n  exolve-width: 3\n  exolve-grid:\n    AB\nexolve-end\n")
    }
    assert_match(/does not match/, e.message)
  end
end
