require_relative 'test_helper'

class PluginTest < PangridTest
  def test_class_to_name
    assert_equal "across-lite-binary", Plugin.class_to_name("Pangrid::AcrossLiteBinary")
    assert_equal "excel-xslx", Plugin.class_to_name("ExcelXSLX")
    assert_equal "png-thumbnail", Plugin.class_to_name("PNGThumbnail")
    assert_equal "json", Plugin.class_to_name("Json")
  end

  def test_registry
    %w(across-lite-binary across-lite-text csv exolve-filled exolve-blank
       json png-thumbnail qxw reddit-filled reddit-blank text).each do |name|
      assert Plugin.get(name), "plugin #{name} not registered"
    end
    assert_nil Plugin.get("no-such-plugin")
  end

  def test_list_all
    out, _ = capture_io { Plugin.list_all }
    assert_match(/across-lite-binary \[FT\]/, out)
    assert_match(/csv \[F\]/, out)
    assert_match(/text \[T\]/, out)
  end

  def test_list_all_shows_features
    out, _ = capture_io { Plugin.list_all }
    assert_match(/^ +bars$/, out)
    assert_match(/^  exolve-filled +\+$/, out)
    assert_match(/^  text +-$/, out)
    assert_match(/bars: bars between squares/, out)
  end

  def test_features
    assert_equal [], Plugin.features
    assert_equal [:bars], Plugin.get("exolve-filled").features
    assert_equal [:bars], Plugin.get("exolve-blank").features
    assert_equal [], Plugin.get("text").features
    assert XWord::FEATURES.keys.include?(:bars)
  end

  def test_unsupported_features
    xw = make_xw
    assert_equal [], Plugin.get("text").unsupported_features(xw)
    xw.solution[0][0].borders = [:right]
    assert_equal [:bars], Plugin.get("text").unsupported_features(xw)
    assert_equal [], Plugin.get("exolve-filled").unsupported_features(xw)
  end

  def test_list_all_reports_missing_deps_and_failures
    Plugin::MISSING_DEPS["fake"] = ["fakegem"]
    Plugin::FAILED << "broken.rb: oops"
    out, _ = capture_io { Plugin.list_all }
    assert_match(/fake: gem install fakegem/, out)
    assert_match(/broken.rb: oops/, out)
  ensure
    Plugin::MISSING_DEPS.delete("fake")
    Plugin::FAILED.delete("broken.rb: oops")
  end

  def test_require_for_plugin
    assert_nil Pangrid.require_for_plugin("ok", ["json"])
    e = assert_raises(PluginDependencyError) do
      Pangrid.require_for_plugin("bad", ["json", "no_such_gem_xyz"])
    end
    assert_equal "bad", e.name
    assert_equal ["no_such_gem_xyz"], e.gems
  end

  def test_load_plugin_records_failures
    Dir.mktmpdir do |dir|
      bad = File.join(dir, "bad_plugin.rb")
      File.write(bad, "raise 'boom'")
      missing = File.join(dir, "missing_plugin.rb")
      File.write(missing, "Pangrid.require_for_plugin('missing', ['no_such_gem_xyz'])")
      unguarded = File.join(dir, "unguarded_plugin.rb")
      File.write(unguarded, "require 'no_such_gem_xyz'")
      Plugin.load_plugin(bad)
      Plugin.load_plugin(missing)
      Plugin.load_plugin(unguarded)
      assert_includes Plugin::FAILED, "bad_plugin.rb: boom"
      assert Plugin::FAILED.any? {|f| f.start_with?("unguarded_plugin.rb: cannot load such file")}
      assert_equal ["no_such_gem_xyz"], Plugin::MISSING_DEPS["missing"]
    ensure
      Plugin::FAILED.reject! {|f| f =~ /^(bad|unguarded)_plugin.rb/}
      Plugin::MISSING_DEPS.delete("missing")
    end
  end

  def test_check
    p = Plugin.new
    assert_nil p.check { true }
    e = assert_raises(PuzzleFormatError) { p.check("bad") { false } }
    assert_equal "bad", e.message
  end

  def test_strip_clue_numbers
    p = Plugin.new
    clues = ["1. One", "2\\. Two", "**3.** Three", "  4 Four", "(5) Five", "Six"]
    assert_equal %w(One Two Three Four Five Six), p.strip_clue_numbers(clues)
  end

  def test_strip_clue_numbers_requires_a_whole_number
    p = Plugin.new
    assert_equal ["1984 author"], p.strip_clue_numbers(["1984 author"], [1])
    assert_equal ["1, 5 Linked clue"], p.strip_clue_numbers(["1, 5 Linked clue"])
    assert_equal ["1. One"], p.strip_clue_numbers(["1. One"], [2])
    assert_equal ["10th"], p.strip_clue_numbers(["10th"])
  end

  def test_strip_clue_numbers_with_expected_numbers
    p = Plugin.new
    assert_equal ["One", "Three"], p.strip_clue_numbers(["1. One", "3. Three"], [1, 3])
    # clues beyond the list of numbers are left as they are
    assert_equal ["One", "2. Two"], p.strip_clue_numbers(["1. One", "2. Two"], [1])
  end

  def test_load_all_is_repeatable
    before = Plugin::REGISTRY.dup
    Plugin.load_all
    assert_equal before, Plugin::REGISTRY
  end
end

require 'tmpdir'
