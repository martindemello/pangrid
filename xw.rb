require 'ostruct'

class XWord < OpenStruct
  # Clue numbering
  def black?(x, y)
    solution[y * width + x] == '.'
  end

  def border?(x, y)
    black?(x, y) || (x < 0) || (y < 0) || (x >= width) || (y >= height)
  end

  def across?(x, y)
    border?(x - 1, y) && !border?(x, y) && !border?(x + 1, y)
  end

  def down?(x, y)
    border?(x, y - 1) && !border?(x, y) && !border?(x, y + 1)
  end

  def number
    n, across, down = 0, [], []
    (0 ... height).each do |y|
      (0 ... width).each do |x|
        across << n if across? x, y
        down << n if down? x, y
        n += 1 if across.last == n || down.last == n
      end
    end
    [across, down]
  end
end
