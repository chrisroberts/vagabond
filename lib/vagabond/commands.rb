require 'mixlib/cli'
require 'chef/log'
require 'vagabond/config'
require 'vagabond/vagabond'
require 'vagabond/server'
require 'vagabond/knife'

module Vagabond
  class Commands

    include Mixlib::CLI

    DEFAULT_ACTIONS = Actions.constants.map do |konst|
      const = Actions.const_get(konst)
      const.public_instance_methods(false) if const.is_a?(Module)
    end.flatten.sort
    
    banner(
      (
        %w(Nodes:) + DEFAULT_ACTIONS.map{ |cmd|
          "\tvagabond #{cmd} NODE [options]"
        }.compact + %w(Server:) + (DEFAULT_ACTIONS + Server.public_instance_methods(false)).sort.map{ |cmd|
          next if cmd == 'server'
          "\tvagabond server #{cmd} [options]"
        }.compact + ['Knife:', "\tvagabond knife COMMAND [knife_options]"] + %w(Options:)
      ).join("\n")
    )
    
    option(:force_solo,
      :long => '--force-configure',
      :boolean => true,
      :default => false
    )

    option(:disable_solo,
      :long => '--disable-configure',
      :boolean => true,
      :default => false
    )
    
    option(:disable_auto_provision,
      :long => '--disable-auto-provision',
      :boolean => true,
      :default => false
    )

    option(:vagabond_file,
      :short => '-f FILE',
      :long => '--vagabond-file FILE'
    )

    option(:disable_local_server,
      :long => '--disable-local-server',
      :boolean => true,
      :default => false
    )

    option(:debug,
      :long => '--debug',
      :boolean => true,
      :default => false
    )
    
    def run!(argv)
      # Turn off Chef logging since we will deal with
      # our own output
      Chef::Log.init('/dev/null')
      parse_options
      name_args = parse_options(argv)
      Config.merge!(config)
      Config[:debug] = STDOUT if Config[:debug]
      case name_args.first.to_s
      when 'server'
        Server.new(name_args.shift, name_args).send(:execute)
      when 'knife'
        Knife.new(name_args.shift, name_args).send(:execute)
      else
        Vagabond.new(name_args.shift, name_args).send(:execute)
      end
    end
  end
end
