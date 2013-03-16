require 'chef/mash'

module Vagabond
  class Vagabondfile

    attr_reader :path
    attr_reader :config

    ALIASES = Mash.new(:boxes => :nodes, :nodes => :boxes)
    
    def initialize(path=nil, *args)
      path = discover_path(Dir.pwd) unless path
      @path = path
      load_configuration!(args.include?(:allow_missing))
    end

    def [](k)
      aliased(k) || @config[k]
    end

    def aliased(k)
      if(ALIASES.has_key?(k))
        v = [@config[k], @config[ALIASES[k]]].compact
        if(v.size > 1)
          case v.first.class
          when Array
            m = :|
          when Hash
            m = :merge
          else
            m = :+
          end
          v.inject(&m)
        else
          v.first
        end
      end
    end
    
    def load_configuration!(no_raise = false)
      if(@path && File.exists?(@path))
        @config = Mash.new(self.instance_eval(IO.read(@path), @path, 1))
      else
        raise 'No Vagabondfile file found!' unless no_raise
        @config = Mash.new
      end
    end

    def discover_path(path)
      d_path = Dir.glob(File.join(path, 'Vagabondfile')).first
      unless(d_path)
        cut_path = path.split(File::SEPARATOR)
        cut_path.pop
        d_path = discover_path(cut_path.join(File::SEPARATOR)) unless cut_path.empty?
      end
      d_path
    end
  end
end
