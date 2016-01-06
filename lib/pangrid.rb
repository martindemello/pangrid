require_relative 'deps/trollop'

require_relative 'pangrid/plugin'

module Pangrid
  def self.run_command_line
    # command line options
    opts = Trollop::options do
      opt :from, "Format to convert from", :type => :string
      opt :to, "Format to convert to", :type => :string
      opt :in, "Input file", :type => :string
      opt :out, "Output file", :type => :string
      opt :list, "List available format plugins"
    end

    run opts
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
