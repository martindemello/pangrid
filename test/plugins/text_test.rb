require_relative '../test_helper'

class TextPluginTest < PangridTest
  def test_write
    assert_equal <<~EOF, Text.new.write(make_xw(grid: %w(CAT A#O BE.)))
      CAT
      A#O
      BE.

      Across:

         1. Feline
         3. Bee sound

      Down:

         1. Taxi
         2. Foot digit
    EOF
  end
end
