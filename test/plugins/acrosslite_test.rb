require_relative '../test_helper'

class ChecksumTest < PangridTest
  def test_of_string
    assert_equal 0, Checksum.of_string("")
    # cksum_region from the puz spec, computed by hand for "AB":
    # 'A' = 65 -> 65; then 65 is odd -> (32 | 0x8000) + 66
    assert_equal 0x8000 + 32 + 66, Checksum.of_string("AB")
  end

  def test_add_string_0_skips_empty
    c = Checksum.new(5)
    c.add_string_0("")
    assert_equal 5, c.sum
    c.add_string_0("A")
    assert_equal Checksum.new(5).tap {|x| x.add_string("A\0")}.sum, c.sum
  end
end

class AcrossLiteBinaryTest < PangridTest
  def roundtrip(xw)
    AcrossLiteBinary.new.read(AcrossLiteBinary.new.write(xw))
  end

  def test_write_header
    out = AcrossLiteBinary.new.write(make_xw)
    assert_equal Encoding::BINARY, out.encoding
    assert_equal "ACROSS&DOWN\0", out[2, 12]
    assert_equal [3, 3, 4], out[0x2c, 6].unpack("C2v")
  end

  def test_roundtrip
    xw = roundtrip(make_xw)
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues
    assert_equal DOWN, xw.down_clues
    assert_equal "Title", xw.title
    assert_equal "Author", xw.author
    assert_equal "Copyright", xw.copyright
    assert_equal "", xw.notes
    assert_equal "1.3", xw.version
  end

  def test_text_is_stored_as_latin1
    xw = make_xw(title: "Café", across: ["Naïve", "Bee sound"])
    out = AcrossLiteBinary.new.write(xw)
    assert_includes out, "Caf\xE9\0".b
    refute_includes out, "Café".b
    read = AcrossLiteBinary.new.read(out)
    assert_equal "Café", read.title
    assert_equal Encoding::UTF_8, read.title.encoding
    assert_equal ["Naïve", "Bee sound"], read.across_clues
  end

  def test_unrepresentable_characters_are_replaced
    out = AcrossLiteBinary.new.write(make_xw(title: "→ x"))
    assert_equal "? x", AcrossLiteBinary.new.read(out).title
  end

  def test_read_does_not_modify_input
    data = AcrossLiteBinary.new.write(make_xw).force_encoding("UTF-8")
    AcrossLiteBinary.new.read(data)
    assert_equal Encoding::UTF_8, data.encoding
  end

  def test_clues_are_interleaved_by_number
    xw = AcrossLiteBinary.new.read(AcrossLiteBinary.new.write(make_xw))
    assert_equal ["Feline", "Taxi", "Foot digit", "Bee sound"], xw.clues
  end

  def test_roundtrip_with_rebus
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    out = roundtrip(xw)
    cell = out.solution[0][0]
    assert cell.rebus?
    assert_equal "CAT", cell.solution.solution
    assert_equal ["GRBS", "RTBL"], out.extensions.map(&:section)
  end

  def test_write_does_not_modify_input
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    first = AcrossLiteBinary.new.write(xw)
    assert_nil xw.clues
    assert_nil xw.extensions
    assert_equal first, AcrossLiteBinary.new.write(xw)
  end

  def test_rewriting_a_rebus_puzzle_does_not_duplicate_extensions
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT")
    once = AcrossLiteBinary.new.write(xw)
    twice = AcrossLiteBinary.new.write(AcrossLiteBinary.new.read(once))
    assert_equal once, twice
  end

  def test_write_rejects_extra_clues
    xw = make_xw(across: ACROSS + ["extra"])
    assert_raises(PuzzleFormatError) { AcrossLiteBinary.new.write(xw) }
    xw = make_xw(down: DOWN + ["extra"])
    assert_raises(PuzzleFormatError) { AcrossLiteBinary.new.write(xw) }
  end

  def test_read_rejects_garbage
    assert_raises(PuzzleFormatError) { AcrossLiteBinary.new.read("not a puzzle".b) }
  end

  def test_read_rejects_scrambled_puzzles
    data = AcrossLiteBinary.new.write(make_xw(scrambled_state: 4))
    e = assert_raises(PuzzleFormatError) { AcrossLiteBinary.new.read(data) }
    assert_match(/Scrambled/, e.message)
  end

  def test_read_rejects_truncated_file
    data = AcrossLiteBinary.new.write(make_xw)
    [20, 0x34, 0x34 + 9].each do |n|
      assert_raises(PuzzleFormatError, "truncated to #{n}") {
        AcrossLiteBinary.new.read(data[0, n])
      }
    end
  end

  def test_read_detects_bad_checksum
    data = AcrossLiteBinary.new.write(make_xw)
    data[0] = (data[0].ord ^ 0xff).chr
    e = assert_raises(PuzzleFormatError) { AcrossLiteBinary.new.read(data) }
    assert_equal "Failed checksum", e.message
  end

  def test_read_ltim_extension
    data = AcrossLiteBinary.new.write(make_xw)
    payload = "42,1"
    ext = ["LTIM", payload.length, Checksum.of_string(payload + "\0")].pack("A4 v2") + payload + "\0"
    xw = AcrossLiteBinary.new.read(data + ext)
    assert_equal 42, xw.time_elapsed
    ltim = xw.extensions.find {|e| e.section == "LTIM"}
    assert ltim.stopped
  end

  def test_read_rejects_unknown_extension
    data = AcrossLiteBinary.new.write(make_xw) + "XXXX\x01\x00\x00\x00a\0"
    assert_raises(PuzzleFormatError) { AcrossLiteBinary.new.read(data) }
  end

  def test_ext_helpers
    w = AcrossLiteBinary.new
    e = Extension.new(elapsed: 10, stopped: false)
    assert_equal "10,0\0", w.send(:write_ltim, e)
    e = Extension.new(grid: [65, 66])
    assert_equal "AB", w.send(:write_gext, e)
    e = Extension.new(data: "AB")
    w.send(:read_gext, e)
    assert_equal [65, 66], e.grid
  end
end

class AcrossLiteTextTest < PangridTest
  def test_write
    out = AcrossLiteText.new.write(make_xw(notes: "line1\nline2"))
    assert_equal <<~EOF, out
      <ACROSS PUZZLE V2>
      <TITLE>
       Title
      <AUTHOR>
       Author
      <COPYRIGHT>
       Copyright
      <SIZE>
       3x3
      <GRID>
       CAT
       A.O
       BEE
      <ACROSS>
       Feline
       Bee sound
      <DOWN>
       Taxi
       Foot digit
      <NOTEPAD>
       line1
       line2
    EOF
  end

  def test_write_fills_in_missing_clues
    out = AcrossLiteText.new.write(make_xw(across: [], down: []))
    assert_equal 4, out.scan("(no clue)").length
  end

  def test_roundtrip
    text = AcrossLiteText.new.write(make_xw(notes: "a note"))
    xw = AcrossLiteText.new.read(text)
    assert_equal 2, xw.version
    assert_equal %w(CAT A#O BEE), grid_strings(xw)
    assert_equal ACROSS, xw.across_clues
    assert_equal DOWN, xw.down_clues
    assert_equal "Title", xw.title
    assert_equal "a note", xw.notes
  end

  def test_roundtrip_with_rebus
    xw = make_xw
    xw.solution[0][0].solution = Rebus.new("CAT", "C")
    xw.solution[2][2].solution = Rebus.new("EEL", "E")
    text = AcrossLiteText.new.write(xw)
    assert_includes text, "<REBUS>\n 1:CAT:C\n 2:EEL:E\n"
    assert_includes text, " 1AT\n"

    out = AcrossLiteText.new.read(text)
    assert_equal "CAT", out.solution[0][0].solution.solution
    assert_equal "EEL", out.solution[2][2].solution.solution
    assert_equal({"CAT" => [1, "C"], "EEL" => [2, "E"]}, out.rebus)
  end

  def test_rebus_mark_flag
    text = "<ACROSS PUZZLE V2>\n<SIZE>\n1x2\n<GRID>\n1A\n<REBUS>\nMARK;\n1:XY:X\n"
    xw = AcrossLiteText.new.read(text)
    assert xw.mark
    assert xw.solution[0][0].rebus?
  end

  def test_v1_does_not_support_rebus
    text = "<ACROSS PUZZLE>\n<SIZE>\n1x2\n<GRID>\n1A\n<REBUS>\n1:XY:X\n"
    assert_raises(PuzzleFormatError) { AcrossLiteText.new.read(text) }
  end

  def test_read_errors
    bad = [
      "garbage\n",
      "<ACROSS PUZZLE>\n<WHAT>\nx\n",
      "<ACROSS PUZZLE>\n<SIZE>\nbig\n",
      "<ACROSS PUZZLE>\n<GRID>\nAB\n",
      "<ACROSS PUZZLE>\n<SIZE>\n1x2\n<GRID>\nABC\n",
      "<ACROSS PUZZLE>\n<TITLE>\na\nb\n",
    ]
    bad.each do |text|
      assert_raises(PuzzleFormatError, text) { AcrossLiteText.new.read(text) }
    end
  end
end
