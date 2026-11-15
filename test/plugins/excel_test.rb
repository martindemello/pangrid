require_relative '../test_helper'

class ExcelTest < PangridTest
  def setup
    skip "axlsx gem not installed" unless Plugin.get("excel-xslx")
  end

  # All the text stored in the workbook
  def workbook_text(xlsx)
    require 'zip'
    text = +""
    Zip::InputStream.open(StringIO.new(xlsx)) do |io|
      while (entry = io.get_next_entry)
        text << io.read.force_encoding("UTF-8") if entry.name.end_with?(".xml")
      end
    end
    text
  end

  def test_write
    out = plugin("excel-xslx").write(make_xw)
    assert out.start_with?("PK"), "expected a zip (xlsx) file"
    assert_includes workbook_text(out), "¹ C"
  end

  def test_write_rebus
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    assert_includes workbook_text(plugin("excel-xslx").write(xw)), "¹ CAT"
  end
end
