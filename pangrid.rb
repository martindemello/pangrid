require_relative 'acrosslite'
require_relative 'text'
require_relative 'excel'

a = AcrossLiteBinary.new
t = XLSX.new
s = IO.read ARGV[0]
File.open("1.xlsx", "w") {|f| f.print t.write(a.read(s))}
