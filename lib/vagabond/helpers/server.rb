module Vagabond
  module Helpers
    module Server
      def setup_server_if_needed
        require 'vagabond/server'
        srv = ::Vagabond::Server.new
        srv.options = options.dup
        unless(vagabondfile.local_chef_server?)
          srv.options[:force_zero] = true
        end
        srv.options[:auto_provision] = true
        unless(srv.lxc.running?)
          vagabondfile.generate_store_path
          internal_config.make_knife_config_if_required(:force)
          srv.up
          knife_config :server_url => "http#{'s' unless srv.lxc.name.include?('zero')}://#{srv.lxc.container_ip(20, true)}"
          srv.send(:upload_cookbooks)
          @srv = srv
        end
        knife_config :server_url => "http#{'s' unless srv.lxc.name.include?('zero')}://#{srv.lxc.container_ip(20, true)}"
      end

      def destroy_server_if_needed
        if(@srv)
          @srv.destroy
        end
      end
    end
  end
end
