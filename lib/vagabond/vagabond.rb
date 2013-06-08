require 'thor'
require 'chef/knife/core/ui'
require 'vagabond/uploader'
require File.join(File.dirname(__FILE__), 'cookbooks/lxc/libraries/lxc.rb')

%w(vagabondfile internal_configuration helpers).each do |dep|
  require "vagabond/#{dep}"
end

Dir.glob(
  File.join(
    File.dirname(__FILE__), 'actions', '*.rb'
  )
).each do |action|
  require "vagabond/actions/#{File.basename(action).sub('.rb', '')}"
end

module Vagabond
  class Vagabond < Thor
    
    include Thor::Actions
    include Helpers

    Actions.constants.each do |const|
      klass = Actions.const_get(const)
      include klass if klass.is_a?(Module)
    end
    
    attr_reader :name
    attr_reader :vagabondfile
    attr_reader :internal_config
    attr_reader :ui
    attr_reader :options

    attr_accessor :mappings_key
    attr_accessor :lxc
    attr_accessor :config
    attr_accessor :action

    CLI_OPTIONS = lambda do
    class_option(:debug,
      :type => :boolean,
      :default => false
    )

    class_option(:force_solo,
      :aliases => '--force-configure',
      :type => :boolean,
      :default => false,
      :desc => 'Force configuration of system'
    )

    class_option(:color,
      :type => :boolean,
      :default => true,
      :desc => 'Enable/disable colorized output'
    )

    class_option(:vagabond_file,
      :aliases => '-f',
      :type => :string,
      :desc => 'Provide path to Vagabondfile'
    )
    
    class_option(:local_server,
      :type => :boolean,
      :default => true,
      :desc => 'Enable/disable local Chef server usage if available'
    )
    end

    CLI_OPTIONS.call

    
    # action:: Action to perform
    # name:: Name of vagabond
    # config:: Hash configuration
    #
    # Creates an instance    
    def initialize(*args)
      super
      @threads = Mash.new
      @mappings_key = :mappings
    end

    ## COMMANDS

    COMMANDS = lambda do |show_node=true|
      Actions.constants.find_all do |const|
        Actions.const_get(const).is_a?(Module)
      end.map(&:to_s).map(&:downcase).each do |meth|
        if(self.respond_to?("_#{meth}_desc"))
          args = self.send("_#{meth}_desc")
        else
          args = ["#{meth}#{' NODE' if show_node}", "#{meth.capitalize} instance#{' of NODE' if show_node}"]
        end
        desc(*args)
        if(self.respond_to?("_#{meth}_options"))
          self.send("_#{meth}_options").each do |opts|
            method_option(*opts)
          end
        end
        define_method meth do |*args|
          setup(meth, *args)
          execute
        end
      end
    end

    COMMANDS.call

    protected

    def version
      setup_ui
      ui.info "#{ui.color('Vagabond:', :yellow, :bold)} - Advocating idleness and work-shyness"
      ui.info "  #{ui.color('Version:', :blue)} - #{VERSION.version} (#{VERSION.codename})"
      exit EXIT_CODES[:success]
    end
    
    def execute
      self.send("_#{@action}")
    end
    
    def setup(action, name=nil, *args)
      @action = action
      @name = name
      @options = options.dup
      if(args.last.is_a?(Hash))
        _ui = args.last.delete(:ui)
        @options.merge!(args.last)
      end
      @leftover_args = args
      setup_ui(_ui)
      load_configurations
      validate! unless action == 'cluster' # TODO -> allow action
      # method to check for validation run
    end

    def name_required!
      unless(name)
        ui.fatal "Node name is required!"
        exit EXIT_CODES[:missing_node_name]
      end
    end

    def provision_solo(path)
      ui.info "#{ui.color('Vagabond:', :bold)} Provisioning node: #{ui.color(name, :magenta)}"
      lxc.container_ip(20) # force wait for container to appear and do so quietly
      direct_container_command(
        "chef-solo -c #{File.join(path, 'solo.rb')} -j #{File.join(path, 'dna.json')}",
        :live_stream => STDOUT
      )
    end
    
    def load_configurations
      @vagabondfile = Vagabondfile.new(options[:vagabond_file], :allow_missing)
      options[:sudo] = sudo
      options[:disable_solo] = true if @action.to_s == 'status' && lxc_installed?
      Chef::Log.init('/dev/null') unless options[:debug]
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(@vagabondfile, ui, options)
      @config = @vagabondfile[:boxes][name]
      @lxc = Lxc.new(@internal_config[mappings_key][name] || '____nonreal____')
      if(options[:local_server] && lxc_installed?)
        if(@vagabondfile[:local_chef_server] && @vagabondfile[:local_chef_server][:enabled])
          srv_name = @internal_config[:mappings][:server]
          srv = Lxc.new(srv_name) if srv_name
          if(srv_name && srv.running?)
            proto = @vagabondfile[:local_chef_server][:zero] ? 'http' : 'https'
            options[:knife_opts] = " --server-url #{proto}://#{srv.container_ip(10, true)}"
          else
            unless(@action.to_sym == :status || name.to_s =='server')
              ui.warn 'Local chef server is not currently running!' unless @action.to_sym == :status
            end
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
      if(name && config.nil? && !options[:disable_name_validate])
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

    def lxc_installed?
      system('which lxc-info > /dev/null')
    end

    def wait_for_completion(type=nil)
      if(type)
        Array(@threads[:type]).map(&:join)
      else
        @threads.values.map do |threads|
          threads.each do |thread_set|
            Array(thread_set).map(&:join)
          end
        end
      end
    end
  end
end
