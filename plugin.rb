def to_hyphen(str)
  str.gsub(/([A-Z]+)([A-Z][a-z])/,'\1-\2').
    gsub(/([a-z\d])([A-Z])/,'\1-\2').
    downcase
end

class Plugin
  REGISTRY = {}

  def self.inherited(subclass)
    name = to_hyphen(subclass.name)
    #puts "Registered #{subclass} as #{name}"
    REGISTRY[name] = subclass
  end

  def self.list_all
    REGISTRY.keys.sort.each do |name|
      plugin = REGISTRY[name]
      provides = [:read, :write].select {|m| plugin.method_defined? m}
      puts name + ": " + provides.join(", ")
    end
  end

end
