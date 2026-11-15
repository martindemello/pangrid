require_relative 'test_helper'
require 'open3'

# Runs bin/pangrid on the sample files in test/testdata:
#
#   1ac2.qxw      grid from qxw, which has no clues
#   1ac2.ans.txt  clues for that grid, in the -c/--clues format
#   1ac2.exolve   expected output: the grid and clues combined
#
# If a writer change alters the expected output, regenerate it with
#
#   ruby -Ilib bin/pangrid -f qxw -t exolve-filled -i test/testdata/1ac2.qxw \
#     -c test/testdata/1ac2.ans.txt -o test/testdata/1ac2.exolve
#
# and check the diff.
class EndToEndTest < PangridTest
  TESTDATA = File.expand_path('testdata', __dir__)
  BIN = File.expand_path('../bin/pangrid', __dir__)
  LIB = File.expand_path('../lib', __dir__)

  def data(name)
    File.join(TESTDATA, name)
  end

  def pangrid(*args)
    out, err, status = Open3.capture3("ruby", "-I", LIB, BIN, *args)
    assert status.success?, "pangrid #{args.join(' ')} failed:\n#{err}"
    out
  end

  def with_output(name)
    Dir.mktmpdir {|dir| yield File.join(dir, name)}
  end

  def test_qxw_with_clues
    %w(-c --clues).each do |flag|
      with_output("1ac2.exolve") do |out|
        pangrid("-f", "qxw", "-t", "exolve-filled",
                "-i", data("1ac2.qxw"), flag, data("1ac2.ans.txt"), "-o", out)
        assert_equal File.read(data("1ac2.exolve")), File.read(out)
      end
    end
  end

  def test_qxw_without_clues_has_placeholders
    with_output("1ac2.exolve") do |out|
      pangrid("-f", "qxw", "-t", "exolve-filled", "-i", data("1ac2.qxw"), "-o", out)
      assert_includes File.read(out), "     7 [PANORAMA]"
    end
  end
end
