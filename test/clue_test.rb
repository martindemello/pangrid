require_relative 'test_helper'

class ClueTest < PangridTest
  def test_parse_splits_enumeration
    c = Clue.parse("  Bird in a tree (5,3) ")
    assert_equal "Bird in a tree", c.text
    assert_equal "5,3", c.enumeration
    assert_equal "Bird in a tree (5,3)", c.to_s
    assert_equal "4-2", Clue.parse("Clue (4-2)").enumeration
    assert_equal "?", Clue.parse("Clue (?)").enumeration
  end

  def test_parse_without_enumeration
    c = Clue.parse("No enum (here)")
    assert_equal "No enum (here)", c.text
    assert_nil c.enumeration
    assert_equal 3, Clue.parse("x", number: 3).number
  end

  def test_coerce
    c = Clue.new("x")
    assert_same c, Clue.coerce(c)
    assert_nil Clue.coerce(nil)
    assert_equal Clue.new("Feline (3)"), Clue.coerce("Feline (3)")
  end

  def test_to_s
    assert_equal "", Clue.new.to_s
    assert_equal "See 1a", Clue.new(parent: ClueRef.new(1, :across)).to_s
    assert_equal "(3)", Clue.new(enumeration: "3").to_s
  end

  def test_lists_default_to_empty
    c = Clue.new(hints: nil)
    Clue::LISTS.each {|f| assert_equal [], c.send(f)}
  end

  def test_equality_and_inspect
    assert_equal Clue.new("a", number: 1), Clue.new("a", number: 1)
    refute_equal Clue.new("a", number: 1), Clue.new("a", number: 2)
    refute_equal Clue.new("a"), "a"
    assert_equal '#<Clue number=1 text="a">', Clue.new("a", number: 1).inspect
  end

  def test_clue_ref
    assert_equal "5", ClueRef.new(5).to_s
    assert_equal "2d", ClueRef.new(2, :down).to_s
  end

  def test_xword_coerces_clue_lists
    xw = XWord.new(across_clues: ["a", nil], nodir_clues: ["n"])
    assert_equal [Clue.new("a"), nil], xw.across_clues
    assert_equal [Clue.new("n")], xw.nodir_clues
    assert_equal [Clue.new("a"), Clue.new("n")], xw.all_clues
  end

  def test_clue_features
    xw = make_xw
    assert_equal [], xw.features
    xw.across_clues[0].explanation = "anno"
    xw.down_clues[0].hints = ["hint"]
    xw.down_clues[1].linked = [ClueRef.new(3, :across)]
    xw.nodir_clues = ["x"]
    assert_equal %i(explanations hints linked_clues nodir_clues), xw.features
  end
end
