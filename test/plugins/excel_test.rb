require_relative '../test_helper'

class ExcelTest < PangridTest
  def test_write
    skip "axlsx gem not installed" unless Plugin.get("excel-xslx")
    out = plugin("excel-xslx").write(make_xw)
    assert out.start_with?("PK"), "expected a zip (xlsx) file"
  end
end
