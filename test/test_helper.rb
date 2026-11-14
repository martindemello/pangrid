# Coverage is optional: run `bundle install` to get simplecov, then
# `rake test` writes an HTML report to coverage/index.html.
begin
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/lib/deps/'
    enable_coverage :branch
  end
rescue LoadError
  # simplecov not installed; run tests without coverage
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'minitest/mock'
require 'tmpdir'
require 'pangrid'

# Plugin.load_all clears the registry and then relies on `require` to
# repopulate it, so it only works once per process (see plugin_test.rb).
Pangrid::Plugin.load_all

module PangridTestHelpers
  include Pangrid

  #   C A T      1 across: CAT   1 down: CAB
  #   A # O      3 across: BEE   2 down: TOE
  #   B E E
  GRID = %w(CAT A#O BEE)
  ACROSS = ["Feline", "Bee sound"]
  DOWN = ["Taxi", "Foot digit"]

  def make_cell(c)
    case c
    when '#' then Cell.new(solution: :black)
    when '.' then Cell.new(solution: :null)
    else Cell.new(solution: c)
    end
  end

  def make_xw(grid: GRID, across: ACROSS, down: DOWN, **extra)
    XWord.new(
      width: grid[0].length,
      height: grid.length,
      solution: grid.map {|row| row.chars.map {|c| make_cell(c)}},
      across_clues: across.dup,
      down_clues: down.dup,
      title: "Title",
      author: "Author",
      copyright: "Copyright",
      **extra
    )
  end

  # Render a grid as strings for easy comparison
  def grid_strings(xw)
    xw.solution.map {|row| row.map(&:inspect).join}
  end

  def plugin(name)
    Plugin.get(name).new
  end
end

class PangridTest < Minitest::Test
  include PangridTestHelpers
end
