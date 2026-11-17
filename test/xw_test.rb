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

  def test_metadata_attributes
    XWord::METADATA.each do |f|
      xw = XWord.new(f => "x")
      assert_equal "x", xw[f]
      assert_equal "x", xw.to_h[f]
    end
  end

  def test_extras_features
    xw = make_xw
    xw.ninas = []
    assert_equal [], xw.features
    xw.ninas = [Nina.new([[0, 0]])]
    xw.questions = [Question.new("Q")]
    xw.misses = {"CAR" => "Close"}
    xw.alternatives = [{[0, 0] => "Z"}]
    assert_equal %i(ninas misses alternatives questions), xw.features
    xw.questions = [Question.new(nil, "4", "CATS")]
    assert_equal %i(ninas misses alternatives final_answer), xw.features
  end

  def test_clues_default_to_empty
    assert_equal [], XWord.new.across_clues
    assert_equal [], XWord.new.down_clues
    assert_equal [], XWord.new(across_clues: nil).across_clues
    xw = XWord.new
    xw.down_clues = nil
    assert_equal [], xw.down_clues.map(&:to_s)
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
    xw.set_bar(2, 1, :top)
    assert_equal [:bars], xw.features
    assert_equal [], XWord.new.features
  end

  def test_numbering_with_bars
    #   A B|C
    #   -
    #   D E F
    xw = make_xw(grid: %w(ABC DEF))
    xw.set_bar(1, 0, :right)
    xw.set_bar(0, 0, :bottom)
    across, down, words_a, words_d = xw.number(true)
    assert_equal [1, 4], across
    assert_equal [2, 3], down
    assert_equal %w(AB DEF), words_a
    assert_equal %w(BE CF), words_d
    assert_equal [1, 2, 3], xw.solution[0].map(&:number)
    assert_equal [4, nil, nil], xw.solution[1].map(&:number)
  end

  def test_bar_seen_from_either_side
    xw = make_xw(grid: %w(AB))
    xw.set_bar(1, 0, :left)
    assert_equal({[0, 0, :right] => :bar}, xw.bars)
    assert xw.bar?(0, 0, :right)
    assert xw.bar?(1, 0, :left)
    refute xw.bar?(1, 0, :right)
    assert_equal [], xw.number[0]
  end

  def test_remove_bar_from_either_side
    xw = make_xw(grid: %w(AB))
    xw.set_bar(0, 0, :right)
    xw.set_bar(1, 0, :left, false)
    assert_empty xw.bars
    refute xw.bar?(0, 0, :right)
    assert_equal [], xw.features
  end

  def test_bars_on_grid_edge_are_ignored
    xw = make_xw(grid: %w(AB CD))
    xw.set_bar(0, 0, :left)
    xw.set_bar(0, 0, :top)
    xw.set_bar(1, 1, :right)
    xw.set_bar(1, 1, :bottom)
    xw.set_bar(5, 5, :right)
    assert_empty xw.bars
    refute xw.bar?(1, 1, :right)
  end

  def test_bar_styles
    xw = make_xw(grid: %w(AB))
    xw.set_bar(0, 0, :right, :dotted)
    assert_equal({[0, 0, :right] => :dotted}, xw.bars)
    refute xw.bar?(0, 0, :right)
    refute_includes xw.features, :bars
  end

  def test_bars_in_to_h
    xw = make_xw(grid: %w(AB))
    refute xw.to_h.key?(:bars)
    xw.set_bar(0, 0, :right)
    assert_equal({[0, 0, :right] => :bar}, xw.to_h[:bars])
  end

  def test_void_squares_are_boundaries
    xw = make_xw(grid: %w(_AB CDE))
    assert xw.boundary?(0, 0)
    refute xw.solution[0][0].light?
    assert_equal [[1, 3], [1, 2]], xw.number
    assert_equal %w(_AB CDE), grid_strings(xw)
    assert_equal [['#', 'A', 'B'], ['C', 'D', 'E']], xw.to_array
    assert_equal [[' ', 'A', 'B'], ['C', 'D', 'E']], xw.to_array(void: ' ')
  end

  def test_labels_do_not_use_up_numbers
    xw = make_xw
    xw.solution[0][2].label = "X"
    across, down = xw.number
    assert_equal [1, 2], across
    assert_equal [1, "X"], down
    assert_nil xw.solution[0][2].number
    assert_equal 2, xw.solution[2][0].number
    xw.solution[0][0].label = ""
    assert_equal [["", 1], ["", "X"]], xw.number
  end

  def test_lights
    xw = make_xw
    assert_equal [Light.new(1, :across, 0, 0), Light.new(1, :down, 0, 0),
                  Light.new(2, :down, 2, 0), Light.new(3, :across, 0, 2)],
                 xw.lights
    assert_equal Light.new(2, :down, 2, 0), xw.light(2, :down)
    assert_nil xw.light(2, :across)
    assert_equal [[2, 0], [2, 1], [2, 2]], xw.light_cells(2, 0, :down)
  end

  def test_cell_features
    {circle: true, color: "red", highlight: true, given: true,
     diagramless: true, label: "A", marks: {"TL" => "1"}}.each do |field, value|
      xw = make_xw
      xw.solution[0][0].send(:"#{field}=", value)
      assert_equal 1, xw.features.length, field
      assert_includes XWord::FEATURES, xw.features[0]
    end
    assert_equal [:void], make_xw(grid: %w(_A BC)).features
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


  def test_cell_defaults
    c = Cell.new(solution: "A", marks: nil)
    assert_equal({}, c.marks)
    assert c.light?
    refute c.void?
    assert Cell.new(solution: :void).void?
    assert_equal "_", Cell.new(solution: :void).to_w
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
