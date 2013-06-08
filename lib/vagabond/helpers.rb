require 'vagabond/constants'
require 'tmpdir'
require 'uuidtools'

module Vagabond
  module Helpers

    RAND_CHARS = ('a'..'z').map(&:to_s) + ('A'..'Z').map(&:to_s) + (0..9).map(&:to_s)
    GEN_NAME_LENGTH = 10
    
    private

    def base_setup
      @options = options.dup
      @vagabondfile = Vagabondfile.new(options[:vagabond_file], :allow_missing)
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      setup_ui
      @internal_config = InternalConfiguration.new(@vagabondfile, ui, options)
    end
    
    def sudo
      case @vagabondfile[:sudo]
      when FalseClass
        ''
      when String
        "#{@vagabondfile[:sudo]} "
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
      seed = Dir.pwd.chars.map(&:ord).inject(&:+)
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
        exit EXIT_CODES[:invalid_action]
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
        true
      rescue
        raise if args[:raise_on_failure]
        false
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
