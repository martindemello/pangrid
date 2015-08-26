require 'trollop'

require_relative 'plugin'

Plugin.load_all

# command line options
opts = Trollop::options do
  opt :from, "Format to convert from", :type => :string
  opt :to, "Format to convert to", :type => :string
  opt :in, "Input file", :type => :string
  opt :out, "Output file", :type => :string
  opt :list, "List available format plugins"
end

if opts[:list]
  puts "Plugins available:"
  puts "----------------------------------------"
  Plugin.list_all
  puts
  puts "Plugin failures:"
  puts Plugin::FAILED.map {|i| "  " + i}
  exit
end

from = Plugin.get(opts[:from])
to = Plugin.get(opts[:to])

if !from or !from.method_defined? :read
  puts "No reader for #{opts[:from]}"
  exit
end

if !to or !to.method_defined? :write
  puts "No writer for #{opts[:to]}"
  exit
end

if !File.exist? opts[:in]
  puts "Cannot find file #{opts[:in]}"
end

reader = from.new
writer = to.new
input = IO.read(opts[:in])
output = writer.write(reader.read(input))
File.open(opts[:out], "w") do |f|
  f.print output
end
