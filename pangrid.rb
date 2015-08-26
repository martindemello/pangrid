require_relative 'plugin'

Plugin.load_all

puts "Plugins available:"
puts "----------------------------------------"
Plugin.list_all
puts
puts Plugin::FAILED


a = AcrossLiteText.new
t = Text.new
s = IO.read ARGV[0]
File.open("1.out", "w") {|f| f.print t.write(a.read(s))}
