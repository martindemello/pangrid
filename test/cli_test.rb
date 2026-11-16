require_relative 'test_helper'
require 'open3'

class CLITest < PangridTest
  def run_pangrid(opts)
    capture_io { Pangrid.run(opts) }
  end

  def run_pangrid_ok(opts)
    result = nil
    capture_io { result = Pangrid.run(opts) }
    result
  end

  def run_bin(*args)
    bin = File.expand_path('../bin/pangrid', __dir__)
    lib = File.expand_path('../lib', __dir__)
    Open3.capture3("ruby", "-I", lib, bin, *args)
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
      assert run_pangrid_ok(from: "json", to: "text", in: input, out: output)
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
      refute run_pangrid_ok(from: "nope", to: "text", in: input, out: output)
      refute File.exist?(output)
    end
  end

  def test_format_errors_are_reported
    with_input("not a csv grid") do |input, output|
      _, err = run_pangrid(from: "csv", to: "text", in: input, out: output)
      assert_match(/^Could not convert .*: No header row found/, err)
      refute run_pangrid_ok(from: "csv", to: "text", in: input, out: output)
      refute File.exist?(output)
    end
  end

  # Run Pangrid.run_command_line in-process. Returns [stdout, stderr, status],
  # where status is the exit status, or nil if it returned without exiting.
  def run_cli(*args)
    status = nil
    out, err = capture_io do
      Pangrid.run_command_line(args)
    rescue SystemExit => e
      status = e.status
    end
    [out, err, status]
  end

  def test_cli_convert
    with_input(Json.new.write(make_xw)) do |input, output|
      _, err, status = run_cli("--from", "json", "--to", "text", "--in", input, "--out", output)
      assert_nil status
      assert_empty err
      assert_equal Text.new.write(make_xw), File.read(output)
    end
  end

  def test_cli_clues
    xw = make_xw(across: ["[CAT]", "[BEE]"], down: ["[CAB]", "[TOE]"])
    with_input(Json.new.write(xw)) do |input, output|
      clues = File.join(File.dirname(input), "clues.txt")
      File.write(clues, ClueListTest::CLUES)
      %w(-c --clues).each do |flag|
        _, err, status = run_cli("-f", "json", "-t", "json", "-i", input, "-o", output, flag, clues)
        assert_nil status, err
        json = JSON.parse(File.read(output))
        assert_equal ["Feline (3)", "Bee sound (3)"], json["across"]
        assert_equal ["Taxi (3)", "Foot digit (3)"], json["down"]
      end
    end
  end

  def test_warns_about_unsupported_features
    barred = File.expand_path('testdata/ny2.qxw', __dir__)
    Dir.mktmpdir do |dir|
      output = File.join(dir, "out")
      _, err = run_pangrid(from: "qxw", to: "text", in: barred, out: output)
      assert_match(/^Warning: text does not support bars between squares/, err)
      assert File.exist?(output), "conversion should still go ahead"
      _, err = run_pangrid(from: "qxw", to: "exolve-filled", in: barred, out: output)
      assert_empty err
    end
  end

  def test_cli_writer_errors
    xw = make_xw(across: ACROSS + ["extra"])
    with_input(Json.new.write(xw)) do |input, output|
      _, err, status = run_cli("-f", "json", "-t", "across-lite-binary", "-i", input, "-o", output)
      assert_equal 1, status
      assert_match(/^Could not convert .*: Extra across clue/, err)
      refute File.exist?(output)
    end
  end

  def test_cli_clue_errors
    with_input(Json.new.write(make_xw)) do |input, output|
      clues = File.join(File.dirname(input), "clues.txt")
      File.write(clues, "Across\n1 Feline\n")
      _, err, status = run_cli("-f", "json", "-t", "text", "-i", input, "-o", output, "-c", clues)
      assert_equal 1, status
      assert_match(/^Could not add clues from .*clues.txt: Clues do not match the grid/, err)
      refute File.exist?(output)

      _, err, status = run_cli("-f", "json", "-t", "text", "-i", input, "-o", output, "-c", clues + "x")
      assert_equal 1, status
      assert_match(/Cannot find file .*clues.txtx/, err)
    end
  end

  def test_cli_short_options
    with_input(Json.new.write(make_xw)) do |input, output|
      _, _, status = run_cli("-f", "json", "-t", "text", "-i", input, "-o", output)
      assert_nil status
      assert_equal Text.new.write(make_xw), File.read(output)
    end
  end

  def test_cli_list
    out, _, status = run_cli("--list")
    assert_nil status
    assert_match(/Available plugins/, out)
    out, _, _ = run_cli("-l")
    assert_match(/Available plugins/, out)
  end

  def test_cli_help
    %w(--help -h).each do |flag|
      out, err, status = run_cli(flag)
      assert_equal 0, status
      assert_match(/^Usage: pangrid/, out)
      assert_match(/--from=FORMAT/, out)
      assert_empty err
    end
  end

  def test_cli_version
    %w(--version -v).each do |flag|
      out, _, status = run_cli(flag)
      assert_equal 0, status
      assert_equal "pangrid #{Pangrid::VERSION}\n", out
    end
  end

  def test_cli_without_arguments_prints_usage
    out, err, status = run_cli
    assert_equal 1, status
    assert_empty out
    assert_match(/^Usage: pangrid/, err)
  end

  def test_cli_incomplete_arguments_prints_usage
    _, err, status = run_cli("--from", "json", "--to", "text")
    assert_equal 1, status
    assert_match(/^Usage: pangrid/, err)
  end

  def test_cli_invalid_options
    _, err, status = run_cli("--bogus")
    assert_equal 1, status
    assert_match(/^Error: invalid option: --bogus/, err)
    assert_match(/Try --help/, err)

    _, err, status = run_cli("--from")
    assert_equal 1, status
    assert_match(/^Error: missing argument: --from/, err)
  end

  def test_cli_conversion_errors
    with_input("not a csv grid") do |input, output|
      _, err, status = run_cli("-f", "csv", "-t", "text", "-i", input, "-o", output)
      assert_equal 1, status
      assert_match(/^Could not convert .*: No header row found/, err)
      refute File.exist?(output)

      _, err, status = run_cli("-f", "nope", "-t", "text", "-i", input, "-o", output)
      assert_equal 1, status
      assert_match(/No reader for nope/, err)
    end
  end

  def test_cli_does_not_modify_argv
    args = ["--version"]
    run_cli(*args)
    assert_equal ["--version"], args
    args = ["-f", "json", "-t", "text"]
    run_cli(*args)
    assert_equal ["-f", "json", "-t", "text"], args
  end

  # Smoke test of the executable itself; the option handling is tested
  # in-process above.
  def test_executable
    with_input(Json.new.write(make_xw)) do |input, output|
      _, _, status = run_bin("--from", "json", "--to", "exolve-filled",
                             "--in", input, "--out", output)
      assert status.success?
      assert_includes File.read(output), "exolve-begin"
    end
    with_input("not a csv grid") do |input, output|
      _, err, status = run_bin("-f", "csv", "-t", "text", "-i", input, "-o", output)
      assert_equal 1, status.exitstatus
      refute_match(/\.rb:\d+/, err, "should not print a backtrace")
    end
  end
end
