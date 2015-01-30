require 'vagabond'

module Vagabond
  class Node

    include Bogo::Memoization
    include Utils::Configuration

    # @return [String] node name
    attr_reader :name
    # @return [String] specialized node classification
    attr_reader :classification

    def initialize(name, vagabondfile, registry, classification=nil)
      @name = name.to_s
      @classification = classification.to_s if classification
      @vagabondfile = vagabondfile
      @registry = registry
      @mapped_name = [classification, name].compact.map(&:to_s).join('__')
    end

    def configuration
      memoize(:configuration) do
        vagabondfile.for_node(name)
      end
    end

    # Run command on node
    #
    # @param command [String] command to run
    # @return [Object]
    def run(command)
      if(exists?)
        box = proxy.connection
        box.disable_safe_mode
        box.execute(command).stdout.join("\n")
      end
    end

    # Instance of node exists
    #
    # @return [TrueClass, FalseClass]
    def exists?
      !!proxy && proxy.exists?
    end

    def state
      exists? ? proxy.state : 'N/A'
    end

    # Create instance of node
    #
    # @return [TrueClass, FalseClass]
    def create!
      unless(exists?)
        instance = Lxc::Ephemeral.new(
          :original => configuration[:template],
          :directory => true,
          :bind => configuration[:bind],
          :union => configuration[:union],
          :daemon => true
        )
        instance.start!(:detach)
        current = local_registry.fetch(:nodes, Smash.new)
        local_registry.set(:nodes, current.merge(mapped_name => instance.name))
        registry.save!
        true
      else
        false
      end
    end

    # Destroy instance of node
    #
    # @return [TrueClass, FalseClass]
    def destroy!
      if(exists?)
        proxy.destroy
        if(local_registry[:nodes])
          local_registry[:nodes].delete(mapped_name)
          registry.save!
        end
        true
      else
        false
      end
    end

    def method_missing(m_name, *args, &block)
      if(proxy.respond_to?(m_name))
        proxy.send(m_name, *args, &block)
      else
        super
      end
    end

    def address
      exists? ? proxy.container_ip : 'N/A'
    end

    def freeze
      if(exists?)
        proxy.freeze
      end
    end

    def thaw
      if(exists?)
        proxy.unfreeze
      end
    end

    protected

    # @return [Object]
    def proxy
      if(internal_name)
        memoize(:proxy) do
          Lxc.new(internal_name)
        end
      end
    end

    # @return [String] physical instance name
    def internal_name
      local_registry.get(:nodes, mapped_name)
    end

    # @return [String] classification name
    def mapped_name
      @mapped_name
    end

    # @return [Vagabondfile]
    def vagabondfile
      @vagabondfile
    end

  end
end
