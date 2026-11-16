require_relative '../test_helper'

class IpuzTest < PangridTest
  #   C A T
  #   A # O      (0, 0) circled, bar right of (1, 0), (2, 2) void
  #   B E _
  SAMPLE = <<~EOF
    {
      "version": "http://ipuz.org/v2",
      "kind": ["http://ipuz.org/crossword#1"],
      "title": "Sample",
      "author": "Setter",
      "editor": "Editor",
      "uniqueid": "sample-1",
      "intro": "Read this first",
      "date": "11/16/2026",
      "dimensions": {"width": 3, "height": 3},
      "styles": {"circled": {"shapebg": "circle"}},
      "puzzle": [
        [{"cell": 1, "style": "circled"}, {"cell": 0, "style": {"barred": "R"}}, 2],
        [0, "#", 0],
        [{"cell": 3, "style": {"color": "FF0000"}}, {"cell": 0, "value": "E"}, null]
      ],
      "solution": [
        ["C", "A", "T"],
        ["A", "#", "O"],
        ["B", {"value": "E"}, null]
      ],
      "clues": {
        "Across": [[1, "Feline"], {"number": 3, "clue": "Letter", "enumeration": "1",
                                    "explanation": "B", "hints": ["Bee"]}],
        "Down:Downwards": [{"number": "1", "clue": "Taxi", "continued": [{"direction": "Across", "number": 3}]},
                           "Toe without its end"],
        "Clues": [{"label": "X", "clue": "Corners", "cells": [[0, 0], [2, 0]]}]
      },
      "answer": "CAT",
      "enumeration": "3",
      "misses": {"DOG": "Wrong animal"}
    }
  EOF

  def read(data = SAMPLE)
    Ipuz.new.read(data)
  end

  def test_read_grid
    xw = read
    assert_equal [3, 3], [xw.width, xw.height]
    assert_equal %w(CAT A#O BE_), grid_strings(xw)
    assert xw.solution[0][0].circle
    assert_equal [:right], xw.solution[0][1].borders
    assert_equal [:left], xw.solution[0][2].borders
    assert_equal "FF0000", xw.solution[2][0].color
    assert xw.solution[2][1].given
    refute xw.solution[0][1].given
  end

  def test_read_metadata
    xw = read
    assert_equal ["Sample", "Setter", "Editor", "sample-1", "Read this first", "11/16/2026"],
                 [xw.title, xw.author, xw.editor, xw.id, xw.preamble, xw.date]
    assert_equal [Question.new(nil, "3", "CAT")], xw.questions
    assert_equal({"DOG" => "Wrong animal"}, xw.misses)
  end

  def test_read_clues
    xw = read
    a1, a3 = xw.across_clues
    assert_equal Clue.new("Feline", number: 1), a1
    assert_equal ["Letter", "1", "B", ["Bee"]], [a3.text, a3.enumeration, a3.explanation, a3.hints]
    d1, d2 = xw.down_clues
    assert_equal 1, d1.number
    assert_equal [ClueRef.new(3, :across)], d1.linked
    assert_equal "Toe without its end", d2.text
    n = xw.nodir_clues[0]
    assert_equal ["X", "Corners", [[0, 0], [2, 0]]], [n.label, n.text, n.cells]
  end

  def test_roundtrip
    w = Ipuz.new
    xw = read
    out = w.write(xw)
    again = w.read(out)
    assert_equal out, w.write(again)
    assert_equal grid_strings(xw), grid_strings(again)
    assert_equal xw.across_clues, again.across_clues
    assert_equal xw.nodir_clues, again.nodir_clues
    assert_equal xw.questions, again.questions
    assert_equal xw.misses, again.misses
    assert again.solution[0][0].circle
    assert again.solution[2][1].given
  end

  def test_write
    out = Ipuz.new.write(read)
    json = JSON.parse(out)
    assert_equal "http://ipuz.org/v2", json["version"]
    assert_equal ["http://ipuz.org/crossword#1"], json["kind"]
    assert_equal({"cell" => 1, "style" => {"shapebg" => "circle"}}, json["puzzle"][0][0])
    assert_equal({"cell" => 0, "style" => {"barred" => "R"}}, json["puzzle"][0][1])
    assert_equal({"cell" => 3, "style" => {"color" => "FF0000"}}, json["puzzle"][2][0])
    assert_equal({"cell" => 0, "value" => "E"}, json["puzzle"][2][1])
    assert_nil json["puzzle"][2][2]
    assert_equal ["C", "A", "T"], json["solution"][0]
    assert_equal [1, "Feline"], json["clues"]["Across"][0]
    assert_equal({"number" => 1, "clue" => "Taxi",
                  "continued" => [{"direction" => "Across", "number" => 3}]},
                 json["clues"]["Down"][0])
    assert_equal [2, "Toe without its end"], json["clues"]["Down"][1]
    assert_equal({"clue" => "Corners", "label" => "X", "cells" => [[0, 0], [2, 0]]},
                 json["clues"]["Clues"][0])
    assert json["showenumerations"]
    assert_equal ["CAT", "3"], [json["answer"], json["enumeration"]]
    assert_includes out, "\n    [\"C\",\"A\",\"T\"],\n"
  end

  def test_write_simple_puzzle
    json = JSON.parse(Ipuz.new.write(make_xw))
    assert_equal [[1, 0, 2], [0, "#", 0], [3, 0, 0]], json["puzzle"]
    assert_equal({"Across" => [[1, "Feline"], [3, "Bee sound"]],
                  "Down" => [[1, "Taxi"], [2, "Foot digit"]]}, json["clues"])
    %w(showenumerations answer misses).each {|k| refute json.key?(k), k}
  end

  def test_write_without_solution_or_clues
    xw = make_xw(grid: %w(.. ..), across: [], down: [])
    json = JSON.parse(Ipuz.new.write(xw))
    refute json.key?("solution")
    refute json.key?("clues")
  end

  def test_labels
    data = JSON.parse(SAMPLE)
    data["puzzle"][0][2] = "T"     # 2 down
    data["puzzle"][2][0] = 0       # 3 across, unnumbered
    data["clues"]["Down"] = [[1, "Taxi"], ["T", "Toe"]]
    data["clues"]["Across"] = [[1, "Feline"], [0, "Letter"]]
    data["clues"].delete("Down:Downwards")
    xw = read(JSON.generate(data))
    assert_equal "T", xw.solution[0][2].label
    assert_equal "", xw.solution[2][0].label
    assert_equal %w(Taxi Toe), xw.down_clues.map(&:text)
    json = JSON.parse(Ipuz.new.write(xw))
    assert_equal ["T", "Toe"], json["clues"]["Down"][1]
    assert_equal({"clue" => "Letter"}, json["clues"]["Across"][1])
    assert_equal "T", json["puzzle"][0][2]
  end

  def test_nonstandard_numbers_become_labels
    data = JSON.parse(SAMPLE)
    data["puzzle"][2][0] = {"cell" => 7}
    data["clues"]["Across"][1]["number"] = 7
    xw = read(JSON.generate(data))
    assert_equal "7", xw.solution[2][0].label
    assert_equal [1, "7"], xw.number[0]
    assert_equal "Letter", xw.across_clues[1].text
  end

  def test_grid_without_numbers_uses_standard_numbering
    data = JSON.parse(SAMPLE)
    data["puzzle"] = [[0, 0, 0], [0, "#", 0], [0, 0, nil]]
    xw = read(JSON.generate(data))
    assert xw.solution.flatten.none?(&:label)
    assert_equal [[1, 3], [1, 2]], xw.number
  end

  def test_linked_child_clue
    xw = make_xw
    xw.down_clues[0].linked = [ClueRef.new(3, :across)]
    xw.across_clues[1] = Clue.new(parent: ClueRef.new(1, :down))
    json = JSON.parse(Ipuz.new.write(xw))
    assert_equal [3, "See 1 Down"], json["clues"]["Across"][1]
  end

  def test_rebus_and_unknown_letters
    xw = make_xw(grid: %w(A. BC))
    xw.solution[0][0].solution = Rebus.new("ANT")
    json = JSON.parse(Ipuz.new.write(xw))
    assert_equal [["ANT", 0], ["B", "C"]], json["solution"]
    read = Ipuz.new.read(JSON.generate(json))
    assert read.solution[0][0].rebus?
    assert_equal "ANT", read.solution[0][0].solution.solution
    assert_equal :null, read.solution[0][1].solution
  end

  def test_read_custom_block_and_empty
    data = {"version" => "http://ipuz.org/v2", "kind" => ["http://ipuz.org/crossword#1"],
            "block" => "*", "empty" => "-", "dimensions" => {"width" => 2, "height" => 2},
            "puzzle" => [["1", "*"], ["-", "-"]]}
    xw = read(JSON.generate(data))
    assert_equal %w(.# ..), grid_strings(xw)
  end

  def test_read_zones_and_marks
    data = JSON.parse(SAMPLE)
    data["zones"] = [{"style" => {"highlight" => true}, "rect" => [0, 0, 1, 0]},
                     {"style" => {"mark" => {"TL" => "a"}}, "cells" => [[2, 1], [9, 9]]}]
    xw = read(JSON.generate(data))
    assert_equal [true, true, nil], xw.solution[0].map(&:highlight)
    assert_equal({"TL" => "a"}, xw.solution[1][2].marks)
    json = JSON.parse(Ipuz.new.write(xw))
    assert_equal({"highlight" => true, "barred" => "R"}, json["puzzle"][0][1]["style"])
    assert_equal({"mark" => {"TL" => "a"}}, json["puzzle"][1][2]["style"])
  end

  def test_multiple_answers
    xw = make_xw(questions: [Question.new(nil, "3", "CAT"), Question.new(nil, nil, "DOG"),
                             Question.new("Ignored", "1", "X")])
    json = JSON.parse(Ipuz.new.write(xw))
    assert_equal ["CAT", "DOG"], json["answers"]
    assert_equal ["3", nil], json["enumerations"]
    read = Ipuz.new.read(JSON.generate(json))
    assert_equal [Question.new(nil, "3", "CAT"), Question.new(nil, nil, "DOG")], read.questions
  end

  def test_jsonp_wrapper
    assert_equal "Sample", read("ipuz(#{SAMPLE});").title
  end

  def test_clues_that_do_not_match_the_grid_keep_their_order
    data = JSON.parse(SAMPLE)
    data["clues"] = {"Across" => [[9, "Nine"], "Unnumbered"]}
    xw = read(JSON.generate(data))
    assert_equal %w(Nine Unnumbered), xw.across_clues.map(&:text)
  end

  def test_errors
    assert_raises(PuzzleFormatError) { read("not json") }
    assert_raises(PuzzleFormatError) { read("[]") }
    assert_raises(PuzzleFormatError) { read('{"version": "x"}') }
    data = JSON.parse(SAMPLE)
    assert_raises(PuzzleFormatError) { read(JSON.generate(data.merge("kind" => ["http://ipuz.org/sudoku#1"]))) }
    assert_raises(PuzzleFormatError) { read(JSON.generate(data.merge("dimensions" => {"width" => 0}))) }
    assert_raises(PuzzleFormatError) { read(JSON.generate(data.merge("puzzle" => [[0]]))) }
    assert_raises(PuzzleFormatError) { read(JSON.generate(data.merge("solution" => [[0]]))) }
  end

  def test_from_exolve
    exolve = <<~EOF
      exolve-begin
        exolve-width: 3
        exolve-height: 3
        exolve-grid:
          C@A T
          A . O
          B|E E
        exolve-across:
          1 Feline (3) Explanation
          Hint: Pet
          3 Bee sound (3)
        exolve-down:
          1, 3a Taxi (3,3)
          2 Foot digit (3)
      exolve-end
    EOF
    xw = ExolveFilled.new.read(exolve)
    assert_empty Ipuz.unsupported_features(xw)
    again = Ipuz.new.read(Ipuz.new.write(xw))
    assert_equal ExolveFilled.new.write(xw), ExolveFilled.new.write(again)
  end
end
