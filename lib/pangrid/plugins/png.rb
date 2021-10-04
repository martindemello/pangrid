require 'chunky_png'

module Pangrid
  
  class PNGThumbnail < Plugin

    def write(xw)
      black = ChunkyPNG::Color::BLACK
      white = ChunkyPNG::Color::WHITE
      red = ChunkyPNG::Color::rgb(255, 0, 0)
      grey = ChunkyPNG::Color::rgb(128, 128, 128)
      scale = 4
      png = ChunkyPNG::Image.new(64, 64, ChunkyPNG::Color::TRANSPARENT)
      xw.each_cell_with_coords do |x, y, cell|
        c = cell.black? ? black : white
        png.rect(
          x * scale, y * scale, (x + 1) * scale, (y + 1) * scale,
          stroke_color = grey, fill_color = c)
      end
      png.rect(0, 0, xw.width * scale, xw.height * scale, stroke_color = red)
      png.to_blob  
    end
  end

end # module Pangrid
