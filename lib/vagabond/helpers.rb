require 'vagabond/constants'
require 'uuidtools'

module Vagabond
  module Helpers
    private
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
      ui.info "#{ui.color('DEBUG:', :red, :bold)} #{s}" if options[:debug]
    end

    def random_name(n=nil)
      n = name unless n
      [n, SecureRandom.hex].compact.join('-')
    end
    
    def generated_name(n=nil)
      n = name unless n
      if(@_gn.nil? || @_gn[n].nil?)
        @_gn ||= Mash.new
        s = Digest::MD5.new
        s << @vagabondfile.path
        @_gn[n] = "#{n}-#{s.hexdigest}"
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
        end
      end
    end
    
  end
end
