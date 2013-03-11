require 'mixlib/cli'
require 'vagabond/config'
require 'vagabond/vagabond'
require 'vagabond/server'

module Vagabond
  class Commands

    include Mixlib::CLI
    
    banner(
      (
        %w(Nodes:) + Vagabond.public_instance_methods(false).sort.map{ |cmd|
          "\tvagabond #{cmd} NODE [options]"
        }.compact + %w(Server:) + Server.public_instance_methods(false).sort.map{ |cmd|
          next if cmd == 'server'
          "\tvagabond server #{cmd} [options]"
        }.compact + %w(Options:)
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
      Config.merge!(config)
      if(name_args.first.to_s == 'server')
        Server.new(name_args.shift, name_args).send(:execute)
      else
        Vagabond.new(name_args.shift, name_args).send(:execute)
      end
    end
  end
end
