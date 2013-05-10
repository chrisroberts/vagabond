require 'thor'
require File.join(File.dirname(__FILE__), 'cookbooks/lxc/libraries/lxc.rb')

%w(helpers vagabondfile internal_configuration).each do |dep|
  require "vagabond/#{dep}"
end

module Vagabond
  class Knife < Thor

    include Thor::Actions
    include Helpers

    def initialize(*args)
      super
    end
    
    desc 'knife COMMAND', 'Run knife commands against local Chef server'
    def knife(command, *args)
      @options = options.dup
      @vagabondfile = Vagabondfile.new(options[:vagabond_file])
      options[:disable_solo] = true
      options[:sudo] = sudo
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(@vagabondfile, nil, options)
      unless(options[:local_server])
        if(@vagabondfile[:local_chef_server] && @vagabondfile[:local_chef_server][:enabled])
          srv = Lxc.new(@internal_config[:mappings][:server])
          if(srv.running?)
            proto = @vagabondfile[:local_chef_server][:zero] ? 'http' : 'https'
            options[:knife_opts] = " --server-url #{proto}://#{srv.container_ip(10, true)}"
          else
            options[:knife_opts] = ' -s https://no-local-server'
          end
        end
      end
      exec("knife #{[command, args].flatten.compact.join(' ')} #{options[:knife_opts]}")
    end

    
  end
end
