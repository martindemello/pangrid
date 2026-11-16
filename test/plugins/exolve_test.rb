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
    assert_equal ACROSS, xw.across_clues
  end

  def test_read_ignores_unknown_sections
    # "own" used to match as a substring of "across down"
    text = "exolve-begin\n  exolve-own:\n    x\n  exolve-grid:\n    AB\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal [], xw.across_clues
    assert_equal [], xw.down_clues
  end

  def test_read_null_cells
    text = "exolve-begin\n  exolve-grid:\n    A0\n    .B\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal %w(A. #B), grid_strings(xw)
  end

  def test_roundtrip_preserves_clues_and_author
    xw = ExolveFilled.new.read(ExolveFilled.new.write(make_xw))
    assert_equal ACROSS, xw.across_clues
    assert_equal DOWN, xw.down_clues
    assert_equal "Author", xw.author
  end

  def test_read_clue_numbers_with_dots
    text = "exolve-begin\n  exolve-grid:\n    AB\n    CD\n  exolve-across:\n    1. One (2)\n    3 Three (2)\nexolve-end\n"
    assert_equal ["One (2)", "Three (2)"], ExolveFilled.new.read(text).across_clues
  end

  def test_read_without_dimensions
    text = "exolve-begin\n  exolve-grid:\n    ABC\n    D.E\nexolve-end\n"
    xw = ExolveFilled.new.read(text)
    assert_equal [3, 2], [xw.width, xw.height]
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
