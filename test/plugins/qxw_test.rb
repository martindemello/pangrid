require_relative '../test_helper'

class QxwTest < PangridTest
  def qxw_for(grid, type: 0)
    out = "#QXW2v4 http://www.quinapalus.com\nGP #{type} #{grid[0].length} #{grid.length} 0 0 0\n"
    grid.each_with_index do |row, y|
      row.chars.each_with_index do |c, x|
        out << "SQ #{x} #{y} 0 0 #{c == '#' ? 1 : 0}\n"
        out << "SQCT #{x} #{y} 0 #{c == '.' ? '' : c}\n" unless c == '#'
      end
    end
    out
  end

  def test_read
    xw = Qxw.new.read(qxw_for(GRID))
    assert_equal 3, xw.width
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal ["[CAT]", "[BEE]"], xw.across_clues
    assert_equal ["[CAB]", "[TOE]"], xw.down_clues
  end

  def test_read_empty_cells
    xw = Qxw.new.read(qxw_for(%w(A. #B)))
    assert_equal %w(A. #B), grid_strings(xw)
  end

  def test_ignores_per_direction_entries
    data = qxw_for(%w(AB)) + "SQCT 0 0 1 Z\n"
    assert_equal %w(AB), grid_strings(Qxw.new.read(data))
  end

  def test_errors
    assert_raises(PuzzleFormatError) { Qxw.new.read("no grid here\n") }
    assert_raises(PuzzleFormatError) { Qxw.new.read(qxw_for(GRID, type: 1)) }
    # missing cells
    truncated = qxw_for(GRID).lines.reject {|l| l.start_with?("SQCT 2 2")}.join
    assert_raises(PuzzleFormatError) { Qxw.new.read(truncated) }
    assert_raises(PuzzleFormatError) { Qxw.new.read(qxw_for(GRID) + "SQ 1\n") }
    assert_raises(PuzzleFormatError) { Qxw.new.read(qxw_for(GRID) + "SQCT 1\n") }
  end
end
