require_relative 'acrosslite'
require_relative 'text'

a = AcrossLiteBinary.new
t = Text.new
s = IO.read ARGV[0]
print t.write(a.read(s))
