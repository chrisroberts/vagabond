module Vagabond
  module Helpers
    module Server

      def server_init!
        srv_node = load_node(:server)
        if(srv_node.exists? && srv_node.running?)
          debug 'Spec found server already running'
        else
          server = Server.new(options)
          server.run_action(:up, :server)
          debug 'Spec started new server instance'
        end
      end

    end
  end
end
