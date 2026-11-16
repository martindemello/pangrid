require_relative '../test_helper'

class QxwTest < PangridTest
  # bars: {[x, y] => bitmask}, bit 0 = right edge, bit 1 = bottom edge
  def qxw_for(grid, type: 0, bars: {})
    out = "#QXW2v4 http://www.quinapalus.com\nGP #{type} #{grid[0].length} #{grid.length} 0 0 0\n"
    grid.each_with_index do |row, y|
      row.chars.each_with_index do |c, x|
        out << "SQ #{x} #{y} #{bars.fetch([x, y], 0)} 0 #{c == '#' ? 1 : 0}\n"
        out << "SQCT #{x} #{y} 0 #{c == '.' ? '' : c}\n" unless c == '#'
      end
    end
    out
  end

  def test_read
    xw = Qxw.new.read(qxw_for(GRID))
    assert_equal 3, xw.width
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal ["[CAT]", "[BEE]"], xw.across_clues.map(&:to_s)
    assert_equal ["[CAB]", "[TOE]"], xw.down_clues.map(&:to_s)
  end

  def test_read_empty_cells
    xw = Qxw.new.read(qxw_for(%w(A. #B)))
    assert_equal %w(A. #B), grid_strings(xw)
  end

  def test_ignores_per_direction_entries
    data = qxw_for(%w(AB)) + "SQCT 0 0 1 Z\n"
    assert_equal %w(AB), grid_strings(Qxw.new.read(data))
  end

  def test_read_bars
    # bar between (0, 0) and (1, 0), and below (2, 0)
    xw = Qxw.new.read(qxw_for(%w(ABC DEF GHI), bars: {[0, 0] => 1, [2, 0] => 2}))
    assert_equal [:right], xw.solution[0][0].borders
    assert_equal [:left], xw.solution[0][1].borders
    assert_equal [:bottom], xw.solution[0][2].borders
    assert_equal [:top], xw.solution[1][2].borders
    assert_equal [], xw.solution[1][1].borders
    assert_equal ["[BC]", "[DEF]", "[GHI]"], xw.across_clues.map(&:to_s)
    assert_equal ["[ADG]", "[BEH]", "[FI]"], xw.down_clues.map(&:to_s)
  end

  def test_ignores_bars_on_grid_edge_and_blocks
    # qxw can leave bar bits set on edge squares and blocks
    xw = Qxw.new.read(qxw_for(%w(A#B CDE), bars: {[2, 0] => 1, [1, 0] => 3, [0, 1] => 2}))
    assert xw.solution.flatten.all? {|c| c.borders.empty?}
  end

  def test_read_barred_sample
    xw = Qxw.new.read(File.read(File.expand_path('../testdata/ny2.qxw', __dir__)))
    assert_equal [8, 10], [xw.width, xw.height]
    assert_equal %w(PILASTER UNITE ONES TIRESOME ENSNARE CYANIDE
                    BEARSKIN ORCS TEETH RETIREES).map {|w| "[#{w}]"},
                 xw.across_clues.map(&:to_s)
    assert_equal %w(PUTTER INSINCERE LIAR ATHENA TENOR ROSE REMEDIATE
                    ANSWER TENTHS YACHT BOAR KNEE).map {|w| "[#{w}]"},
                 xw.down_clues.map(&:to_s)
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
