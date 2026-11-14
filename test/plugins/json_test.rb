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
    assert_equal ACROSS, xw.across_clues
    assert_equal DOWN, xw.down_clues
  end

  def test_read_multi_letter_cell_is_rebus
    json = '{"rows":1,"cols":2,"cells":[{"x":0,"y":0,"contents":"AB"},{"x":1,"y":0,"contents":"C"}],"across":[],"down":[]}'
    xw = Json.new.read(json)
    assert xw.solution[0][0].rebus?
    assert_equal "AB", xw.solution[0][0].solution.solution
  end

  def test_rebus_roundtrip
    skip "known bug: writer emits Rebus#inspect ('[|CAT]') which the reader treats as a literal rebus string"
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    out = Json.new.read(Json.new.write(xw))
    assert_equal "CAT", out.solution[0][0].solution.solution
  end
end
