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

  def test_read_errors
    assert_raises(PuzzleFormatError) { ExolveFilled.new.read("exolve-end\n") }
    assert_raises(PuzzleFormatError) { ExolveFilled.new.read("exolve-begin\n") }
  end
end
