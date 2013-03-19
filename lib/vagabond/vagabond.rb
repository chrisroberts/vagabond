Dir.glob(
  File.join(
    File.dirname(__FILE__), 'actions', '*.rb'
  )
).each do |action_module|
  require action_module
end

require 'vagabond/vagabondfile'
require 'vagabond/internal_configuration'
require 'vagabond/helpers'
require 'chef/knife/core/ui'
require File.join(File.dirname(__FILE__), 'cookbooks/lxc/libraries/lxc.rb')

module Vagabond
  class Vagabond

    include Helpers

    # Load available actions
    Actions.constants.each do |const_sym|
      const = Actions.const_get(const_sym)
      include const if const.is_a?(Module)
    end

    attr_reader :name
    attr_reader :vagabondfile
    attr_reader :internal_config
    attr_reader :ui

    attr_accessor :mappings_key
    attr_accessor :lxc
    attr_accessor :config
    attr_accessor :action
    
    # action:: Action to perform
    # name:: Name of vagabond
    # config:: Hash configuration
    #
    # Creates an instance
    def initialize(action, name_args, args={})
      @mappings_key = :mappings
      setup_ui(args[:ui])
      @action = action
      @name = name_args.shift
      load_configurations
      validate!
    end

    protected

    def provision_solo(path)
      ui.info "#{ui.color('Vagabond:', :bold)} Provisioning node: #{ui.color(name, :magenta)}"
      lxc.container_ip(20) # force wait for container to appear and do so quietly
      direct_container_command(
        "chef-solo -c #{File.join(path, 'solo.rb')} -j #{File.join(path, 'dna.json')}",
        :live_stream => STDOUT
      )
    end
    
    def load_configurations
      @vagabondfile = Vagabondfile.new(Config[:vagabond_file])
      Config[:sudo] = sudo
      Config[:disable_solo] = true if @action.to_sym == :status
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(@vagabondfile, ui)
      @config = @vagabondfile[:boxes][name]
      @lxc = Lxc.new(@internal_config[mappings_key][name] || '____nonreal____')
      unless(Config[:disable_local_server])
        if(@vagabondfile[:local_chef_server] && @vagabondfile[:local_chef_server][:enabled])
          srv = Lxc.new(@internal_config[:mappings][:server])
          if(srv.running?)
            Config[:knife_opts] = " --server-url https://#{srv.container_ip(10, true)}"
          else
            ui.warn 'Local chef server is not currently running!' unless @action.to_sym == :status
            Config[:knife_opts] = ' --server-url https://no-local-server'
          end
        end
      end
    end

    def validate!
      if(name.to_s == 'server')
        ui.fatal "RESERVED node name supplied: #{ui.color(name, :red)}"
        ui.info ui.color("  -> Try: vagabond server #{@action}", :cyan)
        exit EXIT_CODES[:reserved_name]
      end
      if(name && config.nil? && !Config[:disable_name_validate])
        ui.fatal "Invalid node name supplied: #{ui.color(name, :red)}"
        ui.info ui.color("  -> Available: #{vagabondfile[:nodes].keys.sort.join(', ')}", :cyan)
        exit EXIT_CODES[:invalid_name]
      end
    end
    
    def check_existing!
      if(@lxc.exists?)
        ui.error "LXC: #{name} already exists!"
        true
      end
    end
    
    def base_dir
      File.dirname(vagabondfile.path)
    end

    def vagabond_dir
      File.join(base_dir, '.vagabond')
    end
  end
end
