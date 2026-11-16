require 'optparse'

require_relative 'pangrid/version'
require_relative 'pangrid/plugin'
require_relative 'pangrid/clues'

module Pangrid
  def self.option_parser(opts)
    OptionParser.new do |p|
      p.banner = "Usage: pangrid -f FORMAT -t FORMAT -i INPUT -o OUTPUT [-c CLUES]\n" +
                 "       pangrid -l"
      p.version = VERSION
      p.separator ""
      p.separator "Options:"
      p.on("-f", "--from=FORMAT", "Format to convert from") {|v| opts[:from] = v}
      p.on("-t", "--to=FORMAT", "Format to convert to") {|v| opts[:to] = v}
      p.on("-i", "--in=FILE", "Input file") {|v| opts[:in] = v}
      p.on("-o", "--out=FILE", "Output file") {|v| opts[:out] = v}
      p.on("-c", "--clues=FILE", "Add clues from a text file (see README)") {|v|
        opts[:clues] = v
      }
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

    [opts[:in], opts[:clues]].compact.each do |f|
      if !File.exist? f
        $stderr.puts "Cannot find file #{f}"
        return false
      end
    end

    reader = from.new
    writer = to.new
    # Read and write in binary mode so that binary formats (.puz, .png,
    # .xlsx) aren't mangled by newline translation on Windows. Text readers
    # expect UTF-8; the binary reader reinterprets the bytes itself.
    input = File.binread(opts[:in]).force_encoding(Encoding::UTF_8)
    begin
      xw = reader.read(input)
    rescue PuzzleFormatError => e
      $stderr.puts "Could not convert #{opts[:in]}: #{e.message}"
      return false
    end

    if opts[:clues]
      begin
        ClueList.read(File.read(opts[:clues], encoding: "UTF-8")).apply(xw)
      rescue PuzzleFormatError => e
        $stderr.puts "Could not add clues from #{opts[:clues]}: #{e.message}"
        return false
      end
    end

    to.unsupported_features(xw).each do |f|
      $stderr.puts "Warning: #{opts[:to]} does not support " +
                   "#{XWord::FEATURES[f]}; they will be lost"
    end

    begin
      output = writer.write(xw)
    rescue PuzzleFormatError => e
      $stderr.puts "Could not convert #{opts[:in]}: #{e.message}"
      return false
    end
    File.binwrite(opts[:out], output)
    true
  end
end
