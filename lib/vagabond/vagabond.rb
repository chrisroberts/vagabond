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

    class << self
      attr_accessor :ui
    end
    
    # Load available actions
    Actions.constants.each do |const_sym|
      const = Actions.const_get(const_sym)
      include const if const.is_a?(Module)
    end

    attr_reader :name
    attr_reader :lxc
    attr_reader :vagabondfile
    attr_reader :config
    attr_reader :internal_config
    attr_reader :ui

    # action:: Action to perform
    # name:: Name of vagabond
    # config:: Hash configuration
    #
    # Creates an instance
    def initialize(action, name_args)
      setup_ui
      @action = action
      @name = name_args.shift
      load_configurations
      validate!
    end

    def load_configurations
      @vagabondfile = Vagabondfile.new(Config[:vagabond_file])
      Config[:sudo] = sudo
      Config[:disable_solo] = true if @action.to_sym == :status
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(@vagabondfile, ui)
      @config = @vagabondfile[:boxes][name]
      @lxc = Lxc.new(@internal_config[:mappings][name] || '____nonreal____')
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

    protected

    def setup_ui
      Chef::Config[:color] = Config[:color]
      @ui = Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
      self.class.ui = @ui
    end

    def validate!
      if(name.to_s == 'server')
        ui.fatal "Invalid name supplied: #{ui.color(name, :red)}"
        ui.info ui.color("  -> Try: vagabond server #{@action}", :cyan)
        exit -1
      end
    end
    
    def execute
      if(public_methods.include?(@action.to_sym))
        send(@action)
      else
        ui.error "Invalid action received: #{@action}"
      end
    end

    def generate_hash
      Digest::MD5.hexdigest(@vagabondfile.path)
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
