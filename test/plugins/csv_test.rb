require_relative '../test_helper'

class CSVPluginTest < PangridTest
  CSV_INPUT = <<~EOF
    Some title row
    Width: 3, Height: 3, Offset: 0, Black: #, Empty: -, Clues: 1
    C,A,T
    A,#,O
    B,E,-

    ,Feline
    ,Bee sound
    no clue in this row
    ,Taxi
    ,Foot digit
  EOF

  def test_read
    xw = Pangrid::CSV.new.read(CSV_INPUT)
    assert_equal 3, xw.width
    assert_equal 3, xw.height
    assert_equal %w(CAT A#O BE.), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues.map(&:to_s)
    assert_equal DOWN, xw.down_clues.map(&:to_s)
  end

  def test_strips_non_letters_from_cells
    input = "Width: 2, Height: 1, Black: #, Empty: -, Clues: 0\nA1,b!\n"
    xw = Pangrid::CSV.new.read(input)
    assert_equal %w(Ab), grid_strings(xw)
  end

  def test_offset
    input = <<~EOF
      Width: 2, Height: 2, Offset: 1, Black: #, Empty: -, Clues: 0
      row 1,A,B,ignored
      row 2,C,#
    EOF
    xw = Pangrid::CSV.new.read(input)
    assert_equal %w(AB C#), grid_strings(xw)
  end

  def test_too_few_rows
    input = "Width: 2, Height: 3, Black: #, Empty: -, Clues: 0\nA,B\nC,D\n"
    e = assert_raises(PuzzleFormatError) { Pangrid::CSV.new.read(input) }
    assert_match(/Expected 3 grid rows, found 2/, e.message)
  end

  def test_bad_dimensions
    input = "Width: x, Height: 3, Black: #, Empty: -, Clues: 0\nA,B\n"
    assert_raises(PuzzleFormatError) { Pangrid::CSV.new.read(input) }
  end

  def test_missing_header
    e = assert_raises(PuzzleFormatError) { Pangrid::CSV.new.read("a,b\nc,d\n") }
    assert_match(/No header row/, e.message)
  end

  def test_wrong_row_length
    input = "Width: 3, Height: 1, Black: #, Empty: -, Clues: 0\nA,B\n"
    assert_raises(PuzzleFormatError) { Pangrid::CSV.new.read(input) }
  end
end
