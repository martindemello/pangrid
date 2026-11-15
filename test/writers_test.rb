require_relative 'test_helper'

# Every writer should cope with puzzles that are missing some or all clues,
# since several input formats (qxw, exolve, json) may not have any.
class WritersTest < PangridTest
  WRITERS = Plugin::REGISTRY.select {|_, p| p.method_defined?(:write)}.keys

  def assert_all_writers_succeed(xw)
    WRITERS.each do |name|
      out = plugin(name).write(xw.dup)
      refute_nil out, name
    rescue => e
      flunk "#{name}: #{e.class}: #{e.message}"
    end
  end

  def test_no_clues
    assert_all_writers_succeed(make_xw(across: [], down: []))
  end

  def test_json_without_clues
    json = '{"rows":1,"cols":2,"cells":[{"x":0,"y":0,"contents":"A"},{"x":1,"y":0,"contents":"B"}]}'
    assert_all_writers_succeed(Json.new.read(json))
  end

  def test_fewer_clues_than_entries
    assert_all_writers_succeed(make_xw(across: ["Feline"], down: []))
  end

  def test_rebus
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    assert_all_writers_succeed(xw)
  end
end
