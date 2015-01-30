require 'vagabond'
require 'shellwords'
require 'childprocess'

module Vagabond
  # Base command class
  class Command < Bogo::Cli::Command

    include Bogo::Memoization
    include Utils::Configuration

    autoload :Init, 'vagabond/command/init'
    autoload :Knife, 'vagabond/command/knife'
    autoload :Kitchen, 'vagabond/command/kitchen'
    autoload :Spec, 'vagabond/command/spec'
    autoload :Server, 'vagabond/command/server'
    autoload :Status, 'vagabond/command/status'
    autoload :Ssh, 'vagabond/command/ssh'
    autoload :Rebuild, 'vagabond/command/rebuild'
    autoload :Provision, 'vagabond/command/provision'
    autoload :Thaw, 'vagabond/command/thaw'
    autoload :Freeze, 'vagabond/command/freeze'
    autoload :Destroy, 'vagabond/command/destroy'
    autoload :Up, 'vagabond/command/up'
    autoload :Create, 'vagabond/command/create'
    autoload :Cluster, 'vagabond/command/cluster'

    attr_reader :serial

    # Run the requested action.
    #
    # @note This is the method subclasses should override. It will
    #   auto wrap `singleton` methods to ensure conflicting commands
    #   are not run at the same time
    def run!
      raise NotImplementedError
    end

    # Specialized implementation to provide singleton support
    # automatically
    def execute!
      lock_if_serial do
        run!
      end
    end

    protected

    # Return node instance with proper mapped name
    #
    # @param name [String, Symbol] node name
    # @param type [String, Symbol] specialized type (:test, :specs, :clusters)
    # @return [Lxc, NilClass]
    def node(name, type=nil)
      memoize([type, name].compact.join('_')) do
        Node.new(name, vagabondfile, registry, type)
      end
    end

    # Return node cluster
    #
    # @param name [String, Symbol] cluster name
    # @param test [Truthy, Falsey] testing cluster
    # @return [Array<Array<Name, Node>>, NilClass]
    def cluster(name, test=nil)
      collection = test ? :specs : :clusters
      memoize([collection, name].compact.join('_')) do
        clstr = local_registry.get(collection, name)
        if(clstr)
          clstr.map do |i|
            [i.first, Node.new(i.first, vagabondfile, registry, collection)]
          end
        end
      end
    end

    # Execute any available callbacks
    #
    # @param node [Node]
    # @return [TrueClass, FalseClass]
    def run_callbacks(node)
      callbacks = vagabondfile.callbacks_for(node.name)
      action = self.class.name.split('::').last.downcase
      if(callbacks[action])
        [callbacks[action]].flatten.compact.each do |cmd|
          cmd = cmd.gsub('${NAME}', node.name)
          node.run(cmd)
        end
        true
      else
        false
      end
    end

    # @return [Vagabondfile]
    def vagabondfile
      memoize(:vagabondfile, :direct) do
        Vagabondfile.new(options[:vagabondfile])
      end
    end

    # Run command on host machine
    #
    # @param cmd [Array<String>, String] command
    # @param args [Hash] command options
    # @return [TrueClass, FalseClass, String]
    def host_command(cmd, args={})
      cmd = Shellwords.split(cmd) if cmd.is_a?(String)
      process = ChildProcess.build(*cmd)
      process.io.inherit! if args[:stream] || options[:debug] || ENV['DEBUG']
      process.cwd = args[:cwd] if args[:cwd]
      process.start
      process.wait
      unless(process.exit_code == 0)
        raise Error::CommandFailed.new("Failed to run command: `#{cmd.join(' ')}`")
      else
        true
      end
    end

    private

    # Wrap block execution around file lock
    #
    # @yield block to execute
    # @return [Object] result of block execution
    def lock_if_serial
      lockfile = options[:lock_file]
      if(serial)
        File.open(lockfile, File::RDWR|File::CREAT, 0644) do |file|
          if(file.flock(File::LOCK_EX|File::LOCK_NB))
            yield
          else
            raise Error::ProcessLocked.new "Failed to establish lock on file (#{lockfile})"
          end
        end
      else
        yield
      end
    end

  end
end
