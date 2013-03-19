module Vagabond
  class CheffileLoader
    
    attr_reader :cookbooks

    def initialize(path=nil)
      @cookbooks = []
      load(path) if path
    end
    
    def cookbook(name, *args)
      cookbooks[name] = args
    end

    def load(path)
      instance_eval(File.read(path))
    end
      
  end
end
