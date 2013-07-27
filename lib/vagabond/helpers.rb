#encoding: utf-8
require 'vagabond/constants'
require 'tmpdir'
require 'uuidtools'
require 'etc'

module Vagabond
  module Helpers

    RAND_CHARS = ('a'..'z').map(&:to_s) + ('A'..'Z').map(&:to_s) + (0..9).map(&:to_s)
    GEN_NAME_LENGTH = 10
    
    private

    def base_setup
      @options = options.dup
      @vagabondfile = Vagabondfile.new(options[:vagabond_file], :allow_missing)
      Lxc.use_sudo = sudo
      options[:sudo] = sudo
      setup_ui
      @internal_config = InternalConfiguration.new(@vagabondfile, ui, options)
    end
    
    def sudo
      sudo_val = vagabondfile[:sudo]
      if(sudo_val == 'smart')
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
        "#{vagabondfile[:sudo]} "
      else
        'sudo '
      end
    end

    def debug(s)
      ui.info "#{ui.color('DEBUG:', :red, :bold)} #{s}" if options[:debug] && ui
    end

    def random_name(n=nil)
      n = name unless n
      [n, SecureRandom.hex].compact.join('-')
    end
    
    def generated_name(n=nil)
      seed = vagabondfile.directory.chars.map(&:ord).inject(&:+)
      srand(seed)
      n = name unless n
      if(@_gn.nil? || @_gn[n].nil?)
        @_gn ||= Mash.new
        @_gn[n] = "#{n}-"
        GEN_NAME_LENGTH.times do
          @_gn[n] << RAND_CHARS[rand(RAND_CHARS.size)]
        end
      end
      @_gn[n]
    end

    def setup_ui(*args)
      unless(args.first.is_a?(Chef::Knife::UI))
        Chef::Config[:color] = options[:color].nil? ? true : options[:color]
        @ui = Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
      else
        @ui = args.first
      end
      options[:debug] = STDOUT if options[:debug]
      self.class.ui = @ui unless args.include?(:no_class_set)
      @ui
    end

    def execute
      if(public_methods.include?(@action.to_sym))
        send(@action)
      else
        ui.error "Invalid action received: #{@action}"
        raise VagabondError::InvalidAction.new(@action)
      end
    end

    def generate_hash
      Digest::MD5.hexdigest(@vagabondfile.path)
    end

    def direct_container_command(command, args={})
      _lxc = args[:lxc] || lxc
      com = "#{sudo}ssh root@#{lxc.container_ip} -i /opt/hw-lxc-config/id_rsa -oStrictHostKeyChecking=no '#{command}'"
      debug(com)
      begin
        cmd = Mixlib::ShellOut.new(com,
          :live_stream => args[:live_stream] || options[:debug],
          :timeout => args[:timeout] || 1200
        )
        cmd.run_command
        cmd.error!
        cmd
      rescue
        raise if args[:raise_on_failure]
        false
      end
    end

    def via_bundle
      if(defined?(Bundler) && Bundler.bundle_path)
        'bundle exec '
      end
    end

    def build_command(command, args={})
      command = "#{via_bundle}#{command}" unless args[:no_bundle]
      command = "#{sudo}#{command}" if args[:sudo]
      pre_args = args[:shellout] || {}
      debug(command)
      cmd = Mixlib::ShellOut.new(
        command, {
          :live_stream => options[:debug],
          :timeout => 3600
        }
      )
      cmd
    end

    def callbacks(key)
      if(vagabondfile[:callbacks][key])
        ui.info "  Running #{ui.color(key, :bold)} callbacks..."
        if(options[:cluster])
          cluster_name = name
          names = vagabondfile[:clusters][name] if vagabondfile[:clusters]
        else
          names = [name]
        end
        names.each do |n|
          @name = n
          vagabondfile[:callbacks][key].each do |command|
            Array(command.scan(/\$\{(\w+)\}/).first).each do |repl|
              command = command.gsub("${#{repl}}", self.send(repl.downcase))
            end
            ui.info "    Running: #{command}"
            opts = {:timeout => 30}
            opts.merge(vagabondfile[:callbacks][:options] || {})
            cmd = Mixlib::ShellOut.new(command,
              opts.merge(:live_stream => options[:debug])
            )
            cmd.run_command
            if(cmd.status.success?)
              ui.info ui.color('      -> SUCCESS', :green)
            else
              ui.info ui.color("      -> FAILED - (#{cmd.stderr.strip.gsub("\n", ' ')})", :red)
            end
          end
        end
        @name = cluster_name if cluster_name
        ui.info ui.color('  -> COMPLETE', :green)
      end
    end

    class << self
      def included(klass)
        klass.class_eval do
          class << self
            attr_accessor :ui
          end
          attr_accessor :vagabondfile, :internal_config, :name, :ui
        end
      end
    end
  end
end
