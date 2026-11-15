require_relative '../test_helper'

class RedditTest < PangridTest
  CLUES = <<~EOF


    **Across**

      1\\. Feline

      3\\. Bee sound

    **Down**

      1\\. Taxi

      2\\. Foot digit
  EOF

  def test_write_filled
    expected = <<~EOF + CLUES
      |C^1|A|T^2|
      |--|--|--|
      |A|*.*|O|
      |B^3|E|E|
    EOF
    assert_equal expected, RedditFilled.new.write(make_xw)
  end

  def test_write_blank
    expected = <<~EOF + CLUES
      |^1||^2|
      |--|--|--|
      ||*.*||
      |^3|||
    EOF
    assert_equal expected, RedditBlank.new.write(make_xw)
  end

  def test_read_filled_output
    xw = RedditBlank.new.read(RedditFilled.new.write(make_xw))
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues
    assert_equal DOWN, xw.down_clues
  end

  def test_read_blank_output
    xw = RedditBlank.new.read(RedditBlank.new.write(make_xw))
    assert_equal %w(... .#. ...), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues
  end

  def test_read_without_leading_pipes
    text = "C|A|T\n--|--|--\nA|*.*|O\nB|E|E\n\nAcross\n1. Feline\n3. Bee sound\nDown\n1. Taxi\n2. Foot digit\n"
    xw = RedditBlank.new.read(text)
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal DOWN, xw.down_clues
  end

  def test_read_without_grid
    assert_raises(PuzzleFormatError) { RedditBlank.new.read("hello\nworld\n") }
  end
end
