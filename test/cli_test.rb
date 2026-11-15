require_relative 'test_helper'
require 'open3'

class CLITest < PangridTest
  def run_pangrid(opts)
    capture_io { Pangrid.run(opts) }
  end

  def with_input(content)
    Dir.mktmpdir do |dir|
      input = File.join(dir, "in")
      File.write(input, content)
      yield input, File.join(dir, "out")
    end
  end

  def test_convert
    with_input(Json.new.write(make_xw)) do |input, output|
      run_pangrid(from: "json", to: "text", in: input, out: output)
      assert_equal Text.new.write(make_xw), File.read(output)
    end
  end

  def test_binary_roundtrip
    puz = AcrossLiteBinary.new.write(make_xw(title: "Café"))
    with_input(puz) do |input, output|
      run_pangrid(from: "across-lite-binary", to: "across-lite-binary", in: input, out: output)
      assert_equal puz, File.binread(output)
    end
  end

  def test_utf8_text_input
    with_input(AcrossLiteText.new.write(make_xw(title: "Café"))) do |input, output|
      run_pangrid(from: "across-lite-text", to: "exolve-filled", in: input, out: output)
      assert_includes File.read(output, encoding: "UTF-8"), "exolve-title: Café"
    end
  end

  def test_list
    out, _ = run_pangrid(list: true)
    assert_match(/Available plugins/, out)
  end

  def test_errors
    with_input("{}") do |input, output|
      _, err = run_pangrid(from: "nope", to: "text", in: input, out: output)
      assert_match(/No reader for nope/, err)
      _, err = run_pangrid(from: "text", to: "json", in: input, out: output)
      assert_match(/No reader for text/, err)
      _, err = run_pangrid(from: "json", to: "csv", in: input, out: output)
      assert_match(/No writer for csv/, err)
      _, err = run_pangrid(from: "json", to: "text", in: input + "x", out: output)
      assert_match(/Cannot find file/, err)
      refute File.exist?(output)
    end
  end

  def test_executable
    bin = File.expand_path('../bin/pangrid', __dir__)
    lib = File.expand_path('../lib', __dir__)
    with_input(Json.new.write(make_xw)) do |input, output|
      _, status = Open3.capture2e("ruby", "-I", lib, bin,
                                  "--from", "json", "--to", "exolve-filled",
                                  "--in", input, "--out", output)
      assert status.success?
      assert_includes File.read(output), "exolve-begin"
    end
    out, status = Open3.capture2e("ruby", "-I", lib, bin, "--version")
    assert status.success?
    assert_includes out, Pangrid::VERSION
  end
end
