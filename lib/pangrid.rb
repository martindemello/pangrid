require_relative 'deps/trollop'

require_relative 'pangrid/version'
require_relative 'pangrid/plugin'
require_relative 'pangrid/frontend/webrick'

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
      opt :web, "Launch webserver"
    end

    Trollop::with_standard_exception_handling p do
      opts = p.parse ARGV

      if opts[:web]
        run_webserver 1234
      elsif opts[:list] || [:from, :to, :in, :out].all? {|k| opts[k]}
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
    input = IO.read(opts[:in])
    output = writer.write(reader.read(input))
    File.open(opts[:out], "w") do |f|
      f.print output
    end
  end
end
