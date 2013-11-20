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
    attr_reader :missing_ok

    DEFAULT_KEYS = %w(defaults definitions nodes clusters specs server callbacks)
    ALIASES = Mash.new(
      :boxes => :nodes,
      :nodes => :boxes,
      :local_chef_server => :server,
      :server => :local_chef_server
    )

    def initialize(path=nil, args={})
      path = discover_path(args[:command_cwd] || Dir.pwd) unless path
      @path = path
      @missing_ok = args[:allow_missing]
      load_configuration!
    end

    def callbacks_for(name)
      callbacks = self[:callbacks] || Mash.new
      callbacks = Chef::Mixin::DeepMerge.merge(callbacks, for_node(name, :allow_missing)[:callbacks])
      callbacks
    end

    def for_node(name, *args)
      unless(self[:nodes][name] || name.to_sym == :server)
        return Mash.new if args.include?(:allow_missing)
        raise VagabondError::InvalidName.new("Requested name is not a valid node name: #{name}")
      end
      if(self[:nodes][name][:definition])
        base = for_definition(self[:nodes][name][:definition])
      else
        base = self[:defaults]
      end
      if(name.to_sym == :server)
        Chef::Mixin::DeepMerge.merge(base, self[:server][:config] || Mash.new)
      else
        Chef::Mixin::DeepMerge.merge(base, self[:nodes][name])
      end
    end

    def for_definition(name)
      base = self[:defaults]
      unless(self[:definitions][name])
        raise VagabondError::InvalidName.new("Requested name is not a valid definition name: #{name}")
      end
      base = Chef::Mixin::DeepMerge.merge(base, self[:definitions][name])
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

    def load_configuration!
      if(@path && File.exists?(@path))
        thing = self.instance_eval(IO.read(@path), @path, 1)
        if(thing.is_a?(AttributeStruct))
          @config = Mash.new(thing._dump)
        else
          @config = Mash.new(thing)
        end
      end
      unless(@config)
        raise 'No Vagabondfile file found!' unless missing_ok
        @config = Mash[*DEFAULT_KEYS.map{|k| [k, Mash.new]}.flatten]
      end
      generate_store_directory
    end

    def generate_store_directory
      unless(@store_path)
        @store_path = File.join('/tmp/vagabond-solos', directory.gsub(%r{[^0-9a-zA-Z]}, '-'))
        @store_path = File.expand_path(@store_path.gsub('-', '/'))
        FileUtils.mkdir_p(File.dirname(@store_path))
      end
    end

    def store_directory
      @store_path
    end
    alias_method :directory, :store_directory

    def discover_path(path)
      d_path = Dir.glob(File.join(path, 'Vagabondfile')).first
      unless(d_path)
        cut_path = path.split(File::SEPARATOR)
        cut_path.pop
        d_path = discover_path(cut_path.join(File::SEPARATOR)) unless cut_path.empty?
      end
      d_path
    end

    def server?
      self[:server] && !self[:server][:disabled]
    end

  end
end
