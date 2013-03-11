require 'mixlib/cli'
require 'vagabond/config'
require 'vagabond/vagabond'
require 'vagabond/server'

module Vagabond
  class Commands

    include Mixlib::CLI
    
    VALID_COMMANDS = %w(
      up destroy provision status freeze thaw ssh server
    ).sort

    banner(
      (
        VALID_COMMANDS.map{ |cmd|
          next if cmd == 'server'
          "vagabond #{cmd} NODE [options]"
        }.compact + (VALID_COMMANDS + %w(shutdown)).sort.map{ |cmd|
          next if cmd == 'server'
          "vagabond server #{cmd} [options]"
        }.compact
      ).join("\n")
    )
    
    option(:force_solo,
      :long => '--force-solo',
      :boolean => true,
      :default => false
    )

    option(:disable_solo,
      :long => '--disable-solo',
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
    
    def run!(argv)
      parse_options
      name_args = parse_options(argv)
      unless(VALID_COMMANDS.include?(name_args.first))
        raise ArgumentError.new('Invalid command provided!')
      end
      Config.merge!(config)
      if(name_args.first.to_s == 'server')
        Server.new(name_args.shift, name_args).execute
      else
        Vagabond.new(name_args.shift, name_args).execute
      end
    end
  end
end
