require 'chunky_png'

module Pangrid
  
  class PNGThumbnail < Plugin
    attr_reader :scale, :border

    def initialize(scale = 4, border = [128, 0, 0])
      @scale = scale
      @border = border
    end

    def write(xw)
      black = ChunkyPNG::Color::BLACK
      white = ChunkyPNG::Color::WHITE
      grey = ChunkyPNG::Color::rgb(128, 128, 128)
      xdim = xw.width * scale + 2
      ydim = xw.height * scale + 2
      png = ChunkyPNG::Image.new(xdim, ydim, ChunkyPNG::Color::TRANSPARENT)
      xw.each_cell_with_coords do |x, y, cell|
        c = cell.black? ? black : white
        png.rect(
          x * scale, y * scale, (x + 1) * scale, (y + 1) * scale,
          stroke_color = grey, fill_color = c)
      end
      if border
        stroke = ChunkyPNG::Color::rgb(*border)
        png.rect(0, 0, xw.width * scale, xw.height * scale, stroke_color = stroke)
      end
      png.to_blob  
    end
  end

end # module Pangrid
