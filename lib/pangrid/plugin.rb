require_relative 'xw'

module Pangrid

class PluginDependencyError < StandardError
  attr_accessor :name, :gems

  def initialize(name, gems)
    @name, @gems = name, gems
  end
end

# Load all the gem dependencies of a plugin
def self.require_for_plugin(name, gems)
  missing = []
  gems.each do |gem|
    begin
      require gem
    rescue LoadError => e
      # If requiring a gem raises something other than LoadError let it
      # propagate upwards.
      missing << gem
    end
  end
  if !missing.empty?
    raise PluginDependencyError.new(name, missing)
  end
end

class Plugin
  # let all "top level functions" defined directly within the
  # namespace module be available to plugin code.
  include Pangrid

  REGISTRY = {}
  FAILED = []
  MISSING_DEPS = {}

  def self.inherited(subclass)
    name = class_to_name(subclass.name)
    #puts "Registered #{subclass} as #{name}"
    REGISTRY[name] = subclass
  end

  def self.load_all
    REGISTRY.clear
    FAILED.clear
    plugins = Dir.glob(File.dirname(__FILE__) + "/plugins/*.rb")
    plugins.each do |f|
      load_plugin f
    end
  end

  def self.load_plugin(filename)
    begin
      require filename
    rescue PluginDependencyError => e
      MISSING_DEPS[e.name] = e.gems
    rescue StandardError => e
      FAILED << "#{File.basename(filename)}: #{e}"
    end
  end

  def self.list_all
    puts "-------------------------------------------------------"
    puts "Available plugins:"
    puts "-------------------------------------------------------"
    REGISTRY.keys.sort.each do |name|
      plugin = REGISTRY[name]
      provides = [:read, :write].select {|m| plugin.method_defined? m}
      provides = provides.map {|m| {read: 'from', write: 'to'}[m]}
      puts "  " + name + " [" + provides.join(", ") + "]"
    end
    if !MISSING_DEPS.empty?
      puts
      puts "-------------------------------------------------------"
      puts "Missing dependencies for plugins:"
      puts "-------------------------------------------------------"
      MISSING_DEPS.keys.sort.each do |name|
        puts "  " + name + ": gem install " + MISSING_DEPS[name].join(" ")
      end
    end
    if !FAILED.empty?
      puts
      puts "The following plugins could not load due to errors:"
      puts "-------------------------------------------------------"
      FAILED.each do |error|
        puts "  " + error
      end
    end
  end

  def self.get(name)
    REGISTRY[name]
  end

  # utility functions
  def self.class_to_name(str)
    str.gsub(/.*:/, '').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1-\2').
      gsub(/([a-z\d])([A-Z])/,'\1-\2').
      downcase
  end
end

end # module Pangrid
