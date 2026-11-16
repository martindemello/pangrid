require_relative 'test_helper'

class XWordTest < PangridTest
  def test_attributes
    xw = XWord.new(title: "T", width: 2)
    assert_equal "T", xw.title
    assert_equal "T", xw[:title]
    assert_equal "T", xw["title"]
    xw["author"] = "A"
    assert_equal "A", xw.author
    assert_equal({width: 2, title: "T", author: "A", across_clues: [], down_clues: []},
                 xw.to_h)
  end

  def test_clues_default_to_empty
    assert_equal [], XWord.new.across_clues
    assert_equal [], XWord.new.down_clues
    assert_equal [], XWord.new(across_clues: nil).across_clues
    xw = XWord.new
    xw.down_clues = nil
    assert_equal [], xw.down_clues
  end

  def test_unknown_attributes_raise
    assert_raises(NoMethodError) { XWord.new(titel: "T") }
    assert_raises(NoMethodError) { XWord.new.titel }
    assert_raises(NoMethodError) { XWord.new[:titel] }
    assert_raises(NoMethodError) { XWord.new["titel"] = "T" }
  end

  def test_numbering
    xw = make_xw
    across, down = xw.number
    assert_equal [1, 3], across
    assert_equal [1, 2], down
    assert_equal [1, nil, 2], xw.solution[0].map(&:number)
    assert_equal [3, nil, nil], xw.solution[2].map(&:number)
  end

  def test_renumbering_clears_old_numbers
    xw = make_xw
    xw.number
    # blacking out the top left square means (0, 0) no longer starts a word
    xw.solution[0][0].solution = :black
    xw.number
    assert_nil xw.solution[0][0].number
    assert_equal [nil, 1, 2], xw.solution[0].map(&:number)
  end

  def test_numbering_with_words
    _, _, words_a, words_d = make_xw.number(true)
    assert_equal %w(CAT BEE), words_a
    assert_equal %w(CAB TOE), words_d
  end

  def test_single_letters_are_not_words
    xw = make_xw(grid: %w(A#B ##C))
    across, down = xw.number
    assert_equal [], across
    assert_equal [1], down
  end

  def test_null_cells_are_not_boundaries
    # null squares are not black, so they are part of words
    xw = make_xw(grid: %w(A. BC))
    across, down = xw.number
    assert_equal [1, 3], across
    assert_equal [1, 2], down
  end

  def test_features
    xw = make_xw
    assert_equal [], xw.features
    xw.solution[1][2].borders = [:top]
    assert_equal [:bars], xw.features
    assert_equal [], XWord.new.features
  end

  def test_numbering_with_bars
    #   A B|C
    #   -
    #   D E F
    xw = make_xw(grid: %w(ABC DEF))
    xw.solution[0][1].borders = [:right]
    xw.solution[0][0].borders = [:bottom]
    across, down, words_a, words_d = xw.number(true)
    assert_equal [1, 4], across
    assert_equal [2, 3], down
    assert_equal %w(AB DEF), words_a
    assert_equal %w(BE CF), words_d
    assert_equal [1, 2, 3], xw.solution[0].map(&:number)
    assert_equal [4, nil, nil], xw.solution[1].map(&:number)
  end

  def test_bar_on_either_side
    xw = make_xw(grid: %w(AB))
    xw.solution[0][1].borders = [:left]
    assert xw.bar?(0, 0, :right)
    assert xw.bar?(1, 0, :left)
    refute xw.bar?(1, 0, :right)
    assert_equal [], xw.number[0]
  end

  def test_boundary
    xw = make_xw
    assert xw.boundary?(-1, 0)
    assert xw.boundary?(0, -1)
    assert xw.boundary?(3, 0)
    assert xw.boundary?(0, 3)
    assert xw.boundary?(1, 1)
    refute xw.boundary?(0, 0)
  end

  def test_word_from
    xw = make_xw
    assert_equal "CAT", xw.word_from(0, 0, :across)
    assert_equal "TOE", xw.word_from(2, 0, :down)
    assert_equal "", xw.word_from(1, 1, :down)
  end

  def test_to_array_defaults
    xw = make_xw(grid: %w(A# .B))
    assert_equal [['A', '#'], [' ', 'B']], xw.to_array
  end

  def test_to_array_with_options_and_block
    xw = make_xw(grid: %w(A# .B))
    arr = xw.to_array(black: 'X', null: '_') {|c| c.solution.downcase}
    assert_equal [['a', 'X'], ['_', 'b']], arr
  end

  def test_to_array_rejects_unknown_cells
    xw = make_xw
    xw.solution[0][0].solution = 42
    assert_raises(PuzzleFormatError) { xw.to_array }
  end

  def test_each_cell_and_coords
    xw = make_xw
    assert_equal 9, xw.enum_for(:each_cell).count
    coords = xw.enum_for(:each_cell_with_coords).map {|x, y, _| [x, y]}
    assert_equal [0, 0], coords.first
    assert_equal [2, 2], coords.last
    assert_equal [1, 0], coords[1]
  end

  def test_encode_rebus
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    xw.solution[2][2].solution = Rebus.new("EEL", "L")
    xw.encode_rebus!
    assert_equal({"CAT" => [1, "C"], "EEL" => [2, "L"]}, xw.rebus)
    assert_equal "1", xw.solution[0][0].solution.symbol
    assert_equal "2", xw.solution[2][2].solution.symbol
  end

  def test_encode_rebus_with_repeated_solution
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    xw.solution[2][2].solution = Rebus.new("CAT")
    xw.encode_rebus!
    assert_equal({"CAT" => [1, "C"]}, xw.rebus)
    assert_equal "1", xw.solution[2][2].solution.symbol
  end

  def test_inspect_grid
    out = make_xw(grid: %w(AB C#)).inspect_grid
    assert_equal ["1 A", "B", "C", "#"], out.split(/[|\n]/).map(&:strip)
  end
end

class CellTest < PangridTest
  def test_predicates
    assert Cell.new(solution: :black).black?
    refute Cell.new(solution: "A").black?
    assert Cell.new(solution: Rebus.new("AB")).rebus?
    refute Cell.new(solution: "A").rebus?
  end

  def test_has_bar
    c = Cell.new(solution: "A", borders: [:left, :top])
    assert c.has_bar?(:left)
    refute c.has_bar?(:right)
  end

  def test_borders_default_to_empty
    assert_equal [], Cell.new(solution: "A").borders
    assert_equal [], Cell.new(solution: "A", borders: nil).borders
    refute Cell.new(solution: "A").has_bar?(:left)
  end

  def test_to_char
    assert_equal "A", Cell.new(solution: "A").to_char
    assert_equal "R", Cell.new(solution: Rebus.new("REB")).to_char
  end

  def test_to_w_and_inspect
    {:black => '#', :null => '.', 'A' => 'A'}.each do |sol, out|
      assert_equal out, Cell.new(solution: sol).to_w
      assert_equal out, Cell.new(solution: sol).inspect
    end
    assert_equal "[|AB]", Cell.new(solution: Rebus.new("AB")).to_w
  end
end

class RebusTest < PangridTest
  def test_display_char_defaults_to_first_letter
    r = Rebus.new("HEART")
    assert_equal "H", r.display_char
    assert_equal "H", r.to_char
  end

  def test_symbol_takes_precedence
    r = Rebus.new("HEART", "*")
    assert_equal "*", r.to_char
    r.symbol = "3"
    assert_equal "3", r.to_char
    assert_equal "[3|HEART]", r.inspect
  end
end
