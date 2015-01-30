#encoding: utf-8

require 'vagabond'
require 'fileutils'

module Vagabond
  # Infrastructure description file
  class Vagabondfile < Bogo::Config

    include Bogo::Memoization

    attribute :defaults, Smash, :coerce => proc{|v| v.to_smash }
    attribute :definitions, Smash, :coerce => proc{|v| v.to_smash }
    attribute :nodes, Smash, :coerce => proc{|v| v.to_smash }
    attribute :clusters, Smash, :coerce => proc{|v| v.to_smash }
    attribute :specs, Smash, :coerce => proc{|v| v.to_smash }
    attribute :server, Smash, :coerce => proc{|v| v.to_smash }
    attribute :callbacks, Smash, :coerce => proc{|v| v.to_smash }
    attribute :global_cache, String, :default => '/tmp/.vagabond-cache'
    attribute :ssh_user, String, :default => 'root'
    attribute :ssh_key, String, :default => File.join(ENV['HOME'], '.ssh/lxc_container_rsa')
    attribute :ssh_strict, String, :default => 'no'

    # Create new instance
    #
    # @param path [String] path to vagabond file
    # @return [self]
    def initialize(path=nil)
      unless(path)
        path = discover_vagabondfile
      end
      @path = path
      super(path)
      immutable!
      FileUtils.mkdir_p(get(:global_cache))
    end

    # File identifier
    #
    # @return [String]
    def fid
      memoize(:fid) do
        Base64.urlsafe_encode64(path)
      end
    end

    # Callbacks defined for node name
    #
    # @param name [String, Symbol] node name
    # @return [Smash]
    def callbacks_for(name)
      fetch(:callbacks, Smash.new).deep_merge(
        for_node(name, :allow_missing).fetch(
          :callbacks, Smash.new
        )
      )
    end

    # Configuration for defined node name
    #
    # @param name [String, Symbol] node name
    # @return [Smash]
    def for_node(name, *args)
      if(name.to_s == 'server')
        raise Error::InvalidName.new('The `server` name is reserved and cannot be used')
      elsif(get(:nodes, name).nil? && !args.include?(:allow_missing))
        raise Error::InvalidName.new("Requested name not defined within nodes list (`#{name}`)")
      else
        node = get(:nodes, name)
        if(node[:definition])
          base = for_definition(node[:definition])
        else
          base = get(:defaults)
        end
        base.deep_merge(node)
      end
    end

    # Definition for defined node name
    #
    # @param name [String, Symbol] node name
    # @return [Smash]
    def for_definition(name)
      definition = get(:definitions, name)
      unless(definition)
        raise Error::InvalidName.new("Requested name not defined within definitions list (`#{name}`)")
      end
      get(:defaults).deep_merge(definition)
    end

    # @return [String] directory containing vagabondfile
    def directory
      File.dirname(path)
    end

    # @return [TrueClass, FalseClass] local server enabled
    def server?
      !get(:server, :disabled)
    end

    private

    # @return [String] path to file
    def discover_vagabondfile
      cwd = File.expand_path(Dir.pwd)
      file_path = nil
      while(!cwd.empty? && file_path.nil?)
        file_path = File.join(cwd, 'Vagabondfile')
        unless(File.exists?(file_path))
          file_path = nil
          splits = cwd.split(File::SEPARATOR)
          splits.pop
          cwd = splits.join(File::SEPARATOR)
        end
      end
      file_path
    end

  end
end
