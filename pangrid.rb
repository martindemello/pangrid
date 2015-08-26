require_relative 'plugin'

for x in %w(acrosslite reddit text excel)
  begin
    require_relative x
  rescue Exception => e
    STDERR.puts "Could not load #{x}: #{e}"
  end
end

Plugin.list_all

a = AcrossLiteText.new
t = Reddit.new
s = IO.read ARGV[0]
File.open("1.out", "w") {|f| f.print t.write(a.read(s))}
