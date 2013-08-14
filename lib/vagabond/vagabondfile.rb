#encoding: utf-8
require 'chef/mash'
require 'attribute_struct'

module Vagabond
  class Vagabondfile

    class << self
      def describe(&block)
        inst = AttributeStruct.new
        if(block.arity != 1)
          inst.instance_exec(&block)
        else
          inst.instance_exec(inst, &block)
        end
        inst
      end
    end
    
    attr_reader :path
    attr_reader :config

    DEFAULT_KEYS = %w(defaults definitions nodes clusters specs server)
    ALIASES = Mash.new(
      :boxes => :nodes,
      :nodes => :boxes,
      :local_chef_server => :sever,
      :server => :local_chef_server
    )
    
    def initialize(path=nil, *args)
      path = discover_path(Dir.pwd) unless path
      @path = path
      load_configuration!(args.include?(:allow_missing))
    end

    def for_node(name, *args)
      unless(self[:nodes][name])
        return nil if args.include?(:allow_missing)
        raise VagabondError::InvalidName.new("Requested name is not a valid node name: #{name}")
      end
      if(self[:nodes][name][:definition])
        base = for_definition(self[:nodes][name][:definition])
      else
        base = self[:defaults]
      end
      base = Chef::Mixin::DeepMerge.merge(base, self[:nodes][name])
      base
    end

    def for_definition(name)
      base = self[:defaults]
      unless(self[:definitions][name])
        raise VagabondError::InvalidName.new("Requested name is not a valid definition name: #{name}")
      end
      base = Chef::Mixin::DeepMerge.merge(base, self[:definitions][definition])
      base
    end
    
    def [](k)
      if(DEFAULT_KEYS.include?(k.to_s))
        @config[k] ||= Mash.new
      end
      aliased(k) || @config[k]
    end

    def aliased(k)
      if(ALIASES.has_key?(k))
        v = [@config[k], @config[ALIASES[k]]].compact
        if(v.size > 1)
          case v.first
          when Array
            m = :|
          when Hash, Mash
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
    
    def load_configuration!(*args)
      unless(args.empty?)
        no_raise = args.first == true
        force_store = args.include?(:force_store_path)
        no_raise ||= force_store
      end
      if(@path && File.exists?(@path))
        thing = self.instance_eval(IO.read(@path), @path, 1)
        if(thing.is_a?(AttributeStruct))
          @config = Mash.new(thing._dump)
        else
          @config = Mash.new(thing)
        end
      end
      if(!@config || force_store)
        raise 'No Vagabondfile file found!' unless no_raise
        generate_store_path
        @config = Mash[*DEFAULT_KEYS.map{|k| [k, Mash.new]}.flatten]
      end
    end

    def build_private_store
      unless(@_private_store_path)
        @_private_store_path = File.join('/tmp/vagabond-solos', directory.gsub(%r{[^0-9a-zA-Z]}, '-'), 'Vagabondfile')
        @_private_store_path = File.expand_path(@_private_store_path.gsub('-', '/'))
        FileUtils.mkdir_p(File.dirname(@_private_store_path))
        File.dirname(@_private_store_path)
      end
      File.dirname(@_private_store_path)
    end
    
    def generate_store_path
      @path ||= File.expand_path(File.join(Dir.pwd, 'Vagabondfile'))
      unless(@store_path)
        build_private_store
        @store_path = @_private_store_path
      end
      File.dirname(@store_path)
    end

    def store_path
      @store_path || @path
    end

    def directory
      File.dirname(@path)
    end

    def store_directory
      File.dirname(@store_path || @path)
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

    def local_chef_server?
      self[:local_chef_server] && self[:local_chef_server][:enabled]
    end
  end
end
