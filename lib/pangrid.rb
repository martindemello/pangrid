require 'optparse'

require_relative 'pangrid/version'
require_relative 'pangrid/plugin'

module Pangrid
  def self.option_parser(opts)
    OptionParser.new do |p|
      p.banner = "Usage: pangrid -f FORMAT -t FORMAT -i INPUT -o OUTPUT\n" +
                 "       pangrid -l"
      p.version = VERSION
      p.separator ""
      p.separator "Options:"
      p.on("-f", "--from=FORMAT", "Format to convert from") {|v| opts[:from] = v}
      p.on("-t", "--to=FORMAT", "Format to convert to") {|v| opts[:to] = v}
      p.on("-i", "--in=FILE", "Input file") {|v| opts[:in] = v}
      p.on("-o", "--out=FILE", "Output file") {|v| opts[:out] = v}
      p.on("-l", "--list", "List available format plugins") { opts[:list] = true }
      p.on("-v", "--version", "Print version and exit") {
        puts "pangrid #{VERSION}"
        exit
      }
      p.on("-h", "--help", "Show this message") {
        puts p
        exit
      }
    end
  end

  def self.run_command_line(argv = ARGV)
    opts = {}
    parser = option_parser(opts)
    begin
      parser.parse!(argv.dup)
    rescue OptionParser::ParseError => e
      $stderr.puts "Error: #{e.message}"
      $stderr.puts "Try --help for help."
      exit 1
    end

    if opts[:list] || [:from, :to, :in, :out].all? {|k| opts[k]}
      exit 1 unless run opts
    else
      $stderr.puts parser
      exit 1
    end
  end

  # Returns true on success. Errors are reported on stderr.

  def self.run(opts)
    Plugin.load_all

    if opts[:list]
      Plugin.list_all
      return true
    end

    # run the converter
    #
    from = Plugin.get(opts[:from])
    to = Plugin.get(opts[:to])

    if !from or !from.method_defined? :read
      $stderr.puts "No reader for #{opts[:from]}"
      return false
    end

    if !to or !to.method_defined? :write
      $stderr.puts "No writer for #{opts[:to]}"
      return false
    end

    if !File.exist? opts[:in]
      $stderr.puts "Cannot find file #{opts[:in]}"
      return false
    end

    reader = from.new
    writer = to.new
    # Read and write in binary mode so that binary formats (.puz, .png,
    # .xlsx) aren't mangled by newline translation on Windows. Text readers
    # expect UTF-8; the binary reader reinterprets the bytes itself.
    input = File.binread(opts[:in]).force_encoding(Encoding::UTF_8)
    begin
      output = writer.write(reader.read(input))
    rescue PuzzleFormatError => e
      $stderr.puts "Could not convert #{opts[:in]}: #{e.message}"
      return false
    end
    File.binwrite(opts[:out], output)
    true
  end
end
