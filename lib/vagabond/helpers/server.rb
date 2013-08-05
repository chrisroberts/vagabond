module Vagabond
  module Helpers
    module Server
      def setup_server_if_needed
        requrie 'vagabond/server'
        srv = ::Vagabond::Server.new
        srv.options = options.dup
        unless(vagabondfile.local_chef_server?)
          srv.options[:force_zero] = true
        end
        srv.options[:auto_provision] = true
        unless(srv.lxc.running?)
          srv.send(:setup, 'up')
          srv.execute
          srv.send(:upload_cookbooks)
          @srv = srv
        end
      end

      def destroy_server_if_needed
        if(@srv)
          srv.send(:setup, 'destroy')
          srv.send(:execute)
        end
      end
    end
  end
end
