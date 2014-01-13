#encoding: utf-8

require 'vagabond'

module Vagabond
  class Core

    SSH_KEY_BASE = '/opt/hw-lxc-config/id_rsa'
    DISABLE_HOST_SOLO_ON = %w(status init)

    include Mixlib::CLI

    include Helpers::Callbacks
    include Helpers::Chains
    include Helpers::Commands
    include Helpers::Naming
    include Helpers::Nests

    attr_reader :options, :action, :driver

    # options:: options hash
    #
    # Creates an instance
    def initialize(options={})
      @options = Mash.new(options)
      @threads = Mash.new
      @config ||= Mash.new
      Lxc.use_sudo = sudo
      options[:sudo] = sudo
      Settings[:ssh_key] = setup_key!
      setup_ui
      configure
      install_actions
    end

    # Load Vagabondfile
    def vagabondfile
      unless(@vagabondfile)
        @vagabondfile = Vagabondfile.new(options[:vagabond_file])
      end
      @vagabondfile
    end

    # Configure instance based on options and vagabondfile
    def configure
      internal_config
      Chef::Log.init('/dev/null') unless options[:debug]
      @driver = (vagabondfile[:driver] || :lxc).to_sym
      set_server_endpoint
    end

    # If enabled sets chef server endpoint for knife interactions
    def set_server_endpoint
      if(options[:local_server] && vagabondfile.server? && vagabondfile[:mappings][:server])
        proto = vagabondfile[:server][:zero] ? 'http' : 'https'
        srv_name = internal_config[:mappings][:server] || '____nonreal____'
        srv = node_interface(srv_name)
        if(srv.running?)
          knife_config :server_url => "#{proto}://#{srv.container_ip(10, true)}"
        else
          unless(action == :status || name == 'server')
            ui.warn 'Local chef server is not currently running!'
          end
        end
      end
    end

    ## COMMANDS

    # action:: name of action to run
    # name:: name of node
    # opts:: options hash
    # Run requested action on node with provided name
    def run_action(action, name=nil, extra_args=[], opts={})
      if(name.to_s == 'server')
        debug 'Redirecting action request to server instance'
        srv = Server.new(options)
        srv.run_action(action, name, extra_args, opts)
      else
        _options = options.dup
        options.replace(Chef::Mixin::DeepMerge.merge(options, opts))
        result = send(action, *([name, extra_args].flatten(1).compact))
        callbacks(action, name)
        options.replace(_options)
        chain!
        result
      end
    end

    protected

    # Loads actions into instance. Descendents can override this to
    # filter out actions they may not want
    def install_actions
      Actions.modules.each do |_module|
        debug "Loading action module #{_module} into instance of class #{self.class}"
        extend _module
      end
    end

    # Output version information
    def version
      setup_ui
      ui.info "#{ui.color('Vagabond:', :yellow, :bold)} - Advocating idleness and work-shyness"
      ui.info "  #{ui.color('Version:', :blue)} - #{VERSION.version} (#{VERSION.codename})"
    end

    # name:: Name of node
    # Returns `Node` instance
    def load_node(name)
      begin
        Node.new(name,
          :config => vagabondfile.for_node(name),
          :driver => driver
        )
      rescue VagabondError::InvalidName
        ui.fatal "Invalid node name supplied: #{ui.color(name, :red)}"
        ui.info ui.color("  -> Available: #{vagabondfile[:nodes].keys.sort.join(', ')}", :cyan)
        raise
      end
    end

    # Provides ssh key for local user
    def setup_key!
      path = "/tmp/.#{ENV['USER']}_id_rsa"
      unless(File.exists?(path))
        [
          "cp #{SSH_KEY_BASE} #{path}",
          "chown #{ENV['USER']} #{path}",
          "chmod 600 #{path}"
        ].each do |com|
          cmd = build_command(com, :sudo => true)
          cmd.run_command
          cmd.error!
        end
      end
      path
    end

    # Returns the correct sudo command based on vagabondfile and environment
    def sudo
      sudo_val = vagabondfile[:sudo]
      if(sudo_val.nil? || sudo_val.to_s == 'smart')
        if(ENV['rvm_bin_path'] && RbConfig::CONFIG['bindir'].include?(File.dirname(ENV['rvm_bin_path'])))
          sudo_val = 'rvmsudo'
        elsif(Etc.getpwuid.uid == 0)
          sudo_val = false
        else
          sudo_val = true
        end
      end
      case sudo_val
      when FalseClass
        ''
      when String
        "#{sudo_val} "
      else
        'sudo '
      end
    end

    # Setup the UI instance for output
    def setup_ui
      unless(@ui)
        if(Ui.ui)
          @ui = Ui.ui
        else
          Chef::Config[:color] = options[:color]
          ui_class = options[:daemon] ? Ui::Daemon : Ui::Cli
          @ui = ui_class.new($stdout, $stderr, $stdin, {})
          options[:debug] = @ui.debug_stream if options[:debug]
          Ui.ui = @ui
        end
      end
      @ui
    end

    # type:: type of threads to wait on
    # Wait until all threads join
    def wait_for_completion(type=nil)
      @threads ||= []
      if(type)
        Array(@threads[type]).collect{|hsh| hsh[:thread]}.map(&:join)
      else
        @threads.values.flatten.collect{|hsh| hsh[:thread]}.map(&:join)
      end
    end

    # type:: type of tasks
    # Returns hash
    def tasks(type=nil)
      if(type)
        @threads[type] ||= []
        @threads[type]
      else
        @threads
      end
    end

    # s:: String
    # Output debug string
    def debug(s)
      ui.info "#{ui.color('DEBUG:', :red, :bold)} #{s}" if options[:debug] && ui
    end

    # Simple test for lxc locally
    def lxc_installed?
      system('which lxc-info > /dev/null')
    end

  end
end
