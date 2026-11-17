require_relative 'xw'
require_relative 'utils'

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
  include PluginUtils

  REGISTRY = {}
  FAILED = []
  MISSING_DEPS = {}

  DESCRIPTION = ""

  # Features (from XWord::FEATURES) that this format can represent. Plugins
  # that support a feature override this.
  FEATURES = []

  def self.features
    const_get(:FEATURES)
  end

  # Features used by xw that this plugin would lose
  def self.unsupported_features(xw)
    xw.features - features
  end

  def self.inherited(subclass)
    name = class_to_name(subclass.name)
    #puts "Registered #{subclass} as #{name}"
    REGISTRY[name] = subclass
  end

  # Plugins register themselves via `inherited` when their file is first
  # required, so the registry must not be cleared here: `require` will not
  # re-run an already loaded file.
  def self.load_all
    FAILED.clear
    MISSING_DEPS.clear
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
    rescue StandardError, LoadError => e
      # LoadError is not a StandardError; catch it so that one plugin with a
      # missing dependency cannot take down every other plugin.
      FAILED << "#{File.basename(filename)}: #{e}"
    end
  end

  def self.list_all
    puts "-------------------------------------------------------"
    puts "Available plugins (F = from, T = to):"
    puts "-------------------------------------------------------"
    REGISTRY.keys.sort.each do |name|
      plugin = REGISTRY[name]
      provides = [:read, :write].select {|m| plugin.method_defined? m}
      provides = provides.map {|m| {read: 'F', write: 'T'}[m]}.join
      puts "  #{name} [#{provides}]".ljust(30) + plugin.const_get(:DESCRIPTION)
    end
    list_features
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

  # One row per feature, followed by the plugins that support it
  def self.list_features
    puts
    puts "-------------------------------------------------------"
    puts "Features, and the plugins that support them:"
    puts "-------------------------------------------------------"
    XWord::FEATURES.each do |f, desc|
      plugins = REGISTRY.keys.sort.select {|name| REGISTRY[name].features.include?(f)}
      puts "  #{f.to_s.ljust(14)} #{desc}"
      puts "  #{' ' * 14} #{plugins.empty? ? '(none)' : plugins.join(' ')}"
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
