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
    assert_equal ACROSS, xw.across_clues.map(&:to_s)
    assert_equal DOWN, xw.down_clues.map(&:to_s)
  end

  def test_read_blank_output
    xw = RedditBlank.new.read(RedditBlank.new.write(make_xw))
    assert_equal %w(... .#. ...), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues.map(&:to_s)
  end

  def test_read_without_leading_pipes
    text = "C|A|T\n--|--|--\nA|*.*|O\nB|E|E\n\nAcross\n1. Feline\n3. Bee sound\nDown\n1. Taxi\n2. Foot digit\n"
    xw = RedditBlank.new.read(text)
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal DOWN, xw.down_clues.map(&:to_s)
  end

  def read_clues(clues)
    RedditBlank.new.read("|A|B|\n|--|--|\n|C|D|\n\n" + clues)
  end

  def test_clue_number_formats
    xw = read_clues("Across\n**1.** One\n3 Three\nDown\n1\\. Down one\nTwo\n")
    assert_equal ["One", "Three"], xw.across_clues.map(&:to_s)
    # an unnumbered clue is kept rather than dropped
    assert_equal ["Down one", "Two"], xw.down_clues.map(&:to_s)
  end

  def test_number_must_be_a_whole_word
    xw = read_clues("Across\n1. One\n3. Three\nDown\n1984 author\n2. Two\n")
    assert_equal ["1984 author", "Two"], xw.down_clues.map(&:to_s)
  end

  def test_short_clue_section_does_not_swallow_next_section
    xw = read_clues("Across\n1. One\nDown\n1. Down one\n2. Down two\n")
    assert_equal ["One"], xw.across_clues.map(&:to_s)
    assert_equal ["Down one", "Down two"], xw.down_clues.map(&:to_s)
  end

  def test_down_before_across
    xw = read_clues("Down\n1. Down one\n2. Down two\nAcross\n1. One\n3. Three\n")
    assert_equal ["One", "Three"], xw.across_clues.map(&:to_s)
    assert_equal ["Down one", "Down two"], xw.down_clues.map(&:to_s)
  end

  def test_missing_clue_headers
    e = assert_raises(PuzzleFormatError) { read_clues("1. One\n") }
    assert_match(/across/, e.message)
    e = assert_raises(PuzzleFormatError) { read_clues("Across\n1. One\n") }
    assert_match(/down/, e.message)
  end

  def test_read_without_grid
    assert_raises(PuzzleFormatError) { RedditBlank.new.read("hello\nworld\n") }
  end
end
