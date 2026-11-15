require_relative 'deps/trollop'

require_relative 'pangrid/version'
require_relative 'pangrid/plugin'

module Pangrid
  def self.run_command_line
    # command line options
    p = Trollop::Parser.new do
      version "pangrid #{VERSION}"
      opt :from, "Format to convert from", :type => :string
      opt :to, "Format to convert to", :type => :string
      opt :in, "Input file", :type => :string
      opt :out, "Output file", :type => :string
      opt :list, "List available format plugins"
    end

    Trollop::with_standard_exception_handling p do
      opts = p.parse ARGV

      if opts[:list] || [:from, :to, :in, :out].all? {|k| opts[k]}
        run opts
      else
        p.educate
      end
    end
  end

  def self.run(opts)
    Plugin.load_all

    if opts[:list]
      Plugin.list_all
      return
    end

    # run the converter
    #
    from = Plugin.get(opts[:from])
    to = Plugin.get(opts[:to])

    if !from or !from.method_defined? :read
      $stderr.puts "No reader for #{opts[:from]}"
      return
    end

    if !to or !to.method_defined? :write
      $stderr.puts "No writer for #{opts[:to]}"
      return
    end

    if !File.exist? opts[:in]
      $stderr.puts "Cannot find file #{opts[:in]}"
      return
    end

    reader = from.new
    writer = to.new
    # Read and write in binary mode so that binary formats (.puz, .png,
    # .xlsx) aren't mangled by newline translation on Windows. Text readers
    # expect UTF-8; the binary reader reinterprets the bytes itself.
    input = File.binread(opts[:in]).force_encoding(Encoding::UTF_8)
    output = writer.write(reader.read(input))
    File.binwrite(opts[:out], output)
  end
end
