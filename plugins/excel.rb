# Write puzzles out in Excel's .xslx format
#
# Useful primarily for importing a grid into a google spreadsheet for online,
# collaborative solving
#
# provides:
#   ExcelXSLX : write

require_relative '../xw'

require_for_plugin 'excel', ['axlsx']

# styles
STYLES = {
  :black => {:bg_color => "00"},
  :white => {
    :bg_color => "FF", :fg_color => "00",
    :alignment => { :horizontal=> :right },
    :border => Axlsx::STYLE_THIN_BORDER
  }
}

# cobble a cell number together out of unicode superscript chars
SUPERSCRIPTS = %w(⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹)

def format_number(n)
  n.to_s.split(//).map {|c| SUPERSCRIPTS[c.to_i]}.join("").rjust(3)
end

class ExcelXSLX < Plugin
  def write(xw)
    xw.number
    rows = xw.to_array(:black => " ", :null => " ") {|c|
      format_number(c.number) + " " +
      # We can insert the entire word for rebuses
      c.solution
    }

    styles = xw.to_array(:black => :black, :null => :white) {
      :white
    }

    p = Axlsx::Package.new
    wb = p.workbook

    # styles
    wb.styles do |s|
      xstyles = {}
      STYLES.map {|k, v| xstyles[k] = s.add_style v}
      wb.add_worksheet(:name => "Crossword") do |sheet|
        rowstyles = styles.map {|r|
          r.map {|c| xstyles[c]}
        }
        rows.zip(rowstyles).each {|r, s|
          sheet.add_row r, :style => s
        }
      end
    end

    out = p.to_stream(true)
    check("Spreadsheet did not validate") { out }
    out.read
  end
end
