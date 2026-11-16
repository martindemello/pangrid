require_relative '../test_helper'

class JsonPluginTest < PangridTest
  def test_write
    h = JSON.parse(Json.new.write(make_xw(grid: %w(A# .B), across: [], down: ["x"])))
    assert_equal 2, h["rows"]
    assert_equal 2, h["cols"]
    assert_equal [], h["across"]
    assert_equal ["x"], h["down"]
    assert_equal({"x" => 1, "y" => 0, "contents" => "#"}, h["cells"][1])
    assert_equal ["A", "#", "", "B"], h["cells"].map {|c| c["contents"]}
  end

  def test_roundtrip
    xw = Json.new.read(Json.new.write(make_xw(grid: %w(CA# .BE))))
    assert_equal %w(CA# .BE), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues.map(&:to_s)
    assert_equal DOWN, xw.down_clues.map(&:to_s)
  end

  def test_read_multi_letter_cell_is_rebus
    json = '{"rows":1,"cols":2,"cells":[{"x":0,"y":0,"contents":"AB"},{"x":1,"y":0,"contents":"C"}],"across":[],"down":[]}'
    xw = Json.new.read(json)
    assert xw.solution[0][0].rebus?
    assert_equal "AB", xw.solution[0][0].solution.solution
  end

  def test_read_errors
    cell = '{"x":0,"y":0,"contents":"A"}'
    bad = {
      'not json' => /Invalid JSON/,
      '[]' => /JSON object/,
      '{"rows":0,"cols":1,"cells":[]}' => /positive integers/,
      '{"rows":1,"cols":1}' => /cells must be a list/,
      '{"rows":1,"cols":1,"cells":[{"x":1,"y":0,"contents":"A"}]}' => /outside the grid/,
      '{"rows":1,"cols":1,"cells":[{"x":0,"y":0}]}' => /string contents/,
      %({"rows":1,"cols":2,"cells":[#{cell}]}) => /1 cells are missing/,
    }
    bad.each do |json, msg|
      e = assert_raises(PuzzleFormatError, json) { Json.new.read(json) }
      assert_match msg, e.message
    end
  end

  def test_rebus_roundtrip
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    json = Json.new.write(xw)
    assert_equal "CAT", JSON.parse(json)["cells"][0]["contents"]
    out = Json.new.read(json)
    assert out.solution[0][0].rebus?
    assert_equal "CAT", out.solution[0][0].solution.solution
  end
end
