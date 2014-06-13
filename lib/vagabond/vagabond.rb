#encoding: utf-8
require 'thor'
require 'chef/knife/core/ui'
require 'vagabond/uploader'
require 'elecksee/lxc'

%w(constants errors vagabondfile internal_configuration helpers).each do |dep|
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

    DISABLE_HOST_SOLO_ON = %w(status init)

    include Thor::Actions
    include Helpers

    Actions.constants.each do |const|
      klass = Actions.const_get(const)
      include klass if klass.is_a?(Module)
    end

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

      class_option(:callbacks,
        :type => :boolean,
        :default => true,
        :desc => 'Enable/disable action callbacks'
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
          @original_args = args.dup
          unless(args.include?(:no_setup))
            setup(meth, *args)
          end
          result = execute
          callbacks(meth)
          chain!
          result
        end
      end
    end

    COMMANDS.call

    protected

    def attributes
      if(config[:attributes])
        if(config[:attributes].is_a?(Hash))
          JSON.dump(config[:attributes])
        else
          config[:attributes].to_s
        end
      end
    end

    def version
      setup_ui
      ui.info "#{ui.color('Vagabond:', :yellow, :bold)} - Advocating idleness and work-shyness"
      ui.info "  #{ui.color('Version:', :blue)} - #{VERSION.version} (#{CODENAME})"
      exit
    end

    def execute
      self.send("_#{action}")
    end

    def setup(action, name=nil, *args)
      @action = action
      @name = name
      hash_args = args.detect{|x|x.is_a?(Hash)}
      if(hash_args)
        args.delete(hash_args)
        _ui = hash_args.delete(:ui)
        base_setup(_ui)
        config.merge!(hash_args)
      else
        base_setup
      end
      @leftover_args = args
    end

    def name_required!
      unless(name)
        ui.fatal "Node name is required!"
        raise VagabondError::MissingNodeName.new
      end
    end

    def provision_solo(dir)
      ui.info "#{ui.color('Vagabond:', :bold)} Provisioning node: #{ui.color(name, :magenta)}"
      lxc.container_ip(20) # force wait for container to appear and do so quietly
      cmd = direct_container_command(
        "chef-solo -c #{File.join(dir, 'solo.rb')} -j #{File.join(dir, 'dna.json')}",
        :live_stream => STDOUT
      )
      raise VagabondError::NodeProvisionFailed.new("Failed to provision: #{name}") unless cmd
    end

    def validate!
      if(name.to_s == 'server')
        ui.fatal "RESERVED node name supplied: #{ui.color(name, :red)}"
        ui.info ui.color("  -> Try: vagabond server #{action}", :cyan)
        raise VagabondError::ReservedName.new(name)
      end
      if(name && config.nil? && !options[:disable_name_validate])
        ui.fatal "Invalid node name supplied: #{ui.color(name, :red)}"
        ui.info ui.color("  -> Available: #{vagabondfile[:nodes].keys.sort.join(', ')}", :cyan)
        raise VagabondError::InvalidName.new(name)
      end
    end

    def check_existing!
      if(lxc.exists?)
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

    def wait_for_completion(type=nil)
      @threads ||= []
      if(type)
        Array(@threads[type]).collect{|hsh| hsh[:thread]}.map(&:join)
      else
        @threads.values.flatten.collect{|hsh| hsh[:thread]}.map(&:join)
      end
    end

    def tasks(type=nil)
      type ? @threads[type] : @threads
    end
  end
end
