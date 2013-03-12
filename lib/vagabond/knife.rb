require 'vagabond/helpers'

module Vagabond
  class Knife

    include Helpers

    attr_reader :name_args
    
    def initialize(name, name_args)
      @name_args = name_args
      @vagabondfile = Vagabondfile.new(Config[:vagabond_file])
      Config[:disable_solo] = true
      Config[:sudo] = sudo
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(@vagabondfile, nil)
      unless(Config[:disable_local_server])
        if(@vagabondfile[:local_chef_server] && @vagabondfile[:local_chef_server][:enabled])
          srv = Lxc.new(@internal_config[:mappings][:server])
          if(srv.running?)
            Config[:knife_opts] = " -s https://#{srv.container_ip(10, true)}"
          else
            Config[:knife_opts] = ' -s https://no-local-server'
          end
        end
      end

    end

    def execute
      exec("knife #{name_args.join(' ')} #{Config[:knife_opts]}")
    end

    
  end
end
