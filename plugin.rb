def to_hyphen(str)
  str.gsub(/([A-Z]+)([A-Z][a-z])/,'\1-\2').
    gsub(/([a-z\d])([A-Z])/,'\1-\2').
    downcase
end

class Plugin
  REGISTRY = {}
  FAILED = []

  def self.inherited(subclass)
    name = to_hyphen(subclass.name)
    #puts "Registered #{subclass} as #{name}"
    REGISTRY[name] = subclass
  end

  def self.load_all
    REGISTRY.clear
    FAILED.clear
    plugins = Dir.glob(File.dirname(__FILE__) + "/plugins/*.rb")
    plugins.each do |f|
      begin
        require f
      rescue StandardError, LoadError => e
        FAILED << "Could not load #{File.basename(f)}: #{e}"
      end
    end
  end

  def self.list_all
    REGISTRY.keys.sort.each do |name|
      plugin = REGISTRY[name]
      provides = [:read, :write].select {|m| plugin.method_defined? m}
      puts name + ": " + provides.join(", ")
    end
  end

  def self.get(name)
    REGISTRY[name]
  end
end
