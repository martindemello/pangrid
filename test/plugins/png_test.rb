require_relative '../test_helper'

class PNGThumbnailTest < PangridTest
  def test_write
    blob = PNGThumbnail.new.write(make_xw)
    img = ChunkyPNG::Image.from_blob(blob)
    assert_equal [14, 14], [img.width, img.height]
    # centre of the black square
    assert_equal ChunkyPNG::Color::BLACK, img[6, 6]
    assert_equal ChunkyPNG::Color::WHITE, img[2, 2]
    # border
    assert_equal ChunkyPNG::Color.rgb(128, 0, 0), img[0, 0]
  end

  def test_void_squares_are_drawn_black
    img = ChunkyPNG::Image.from_blob(PNGThumbnail.new.write(make_xw(grid: %w(_A BC))))
    assert_equal ChunkyPNG::Color::BLACK, img[2, 2]
  end

  def test_custom_scale_and_no_border
    img = ChunkyPNG::Image.from_blob(PNGThumbnail.new(10, nil).write(make_xw))
    assert_equal [32, 32], [img.width, img.height]
    assert_equal ChunkyPNG::Color.rgb(128, 128, 128), img[0, 0]
  end
end
