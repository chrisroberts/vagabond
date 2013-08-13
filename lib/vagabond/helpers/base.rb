#encoding: utf-8

require 'vagabond/constants'
require 'etc'

module Vagabond
  module Helpers

    module Base
      
      def base_setup(*args)
        @options = @options.dup
        @vagabondfile = Vagabondfile.new(options[:vagabond_file], :allow_missing)
        Lxc.use_sudo = sudo
        options[:sudo] = sudo
        setup_ui(*args)
        config_args = args.detect{|i| i.is_a?(Hash) && i[:config]} || {}
        @internal_config = InternalConfiguration.new(@vagabondfile, ui, options, config_args[:config] || {})
        configure
        validate_if_required
        Chef::Log.init('/dev/null') unless options[:debug]
      end

      def configure
        @config = vagabondfile[:nodes][name]
        @lxc = Lxc.new(internal_config[mappings_key][name] || '____nonreal____')
        if(options[:local_server] && vagabondfile.local_chef_server? && lxc_installed?)
          proto = vagabondfile[:local_chef_server][:zero] ? 'http' : 'https'
          srv_name = internal_config[:mappings][:server] || '____nonreal____'
          srv = Lxc.new(srv_name)
          if(srv.running?)
            knife_config :server_url => "#{proto}://#{srv.container_ip(10, true)}"
          else
            unless(action.to_s == 'status' || name.to_s =='server')
              ui.warn 'Local chef server is not currently running!'
            end
          end
        end
      end

      def validate_if_required
        if(respond_to?(check = "#{action}_validate?".to_sym))
          validate! if send(check)
        else
          validate!
        end
      end
      
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

      def debug(s)
        ui.info "#{ui.color('DEBUG:', :red, :bold)} #{s}" if options[:debug] && ui
      end

      def setup_ui(*args)
        unless(@ui)
          unless(args.first.is_a?(Chef::Knife::UI))
            Chef::Config[:color] = options[:color].nil? ? true : options[:color]
            @ui = Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
          else
            @ui = args.first
          end
          options[:debug] = STDOUT if options[:debug]
          self.class.ui = @ui unless args.include?(:no_class_set)
        end
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

      class << self
        def included(klass)
          klass.class_eval do
            class << self
              attr_accessor :ui
            end
            attr_accessor :vagabondfile, :internal_config, :name, :ui, :options, :leftover_args
          end
        end
      end

    end
  end
end
