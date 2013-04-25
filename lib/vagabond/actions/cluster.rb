module Vagabond
  module Actions
    module Cluster
      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _cluster_options
                [[:auto_provision, :type => :boolean, :default => true]]
              end
            end
          end
        end
      end

      def _cluster
        clr = vagabondfile[:clusters][name] if vagabondfile[:clusters]
        if(clr)
          ui.info "#{ui.color('Vagabond:', :bold)} Building cluster - #{ui.color(name, :green)}"
          if(vagabondfile[:local_chef_server] && vagabondfile[:local_chef_server][:enabled])
            require 'vagabond/server'
            srv = ::Vagabond::Server.new
            srv.send(:setup, 'up')
            srv.execute
          end
          clr.each do |n|
            @name = n
            @config = @vagabondfile[:boxes][name]
            @lxc = Lxc.new(@internal_config[mappings_key][name] || '____nonreal____')
            _up
          end
          ui.info "  -> #{ui.color("Built cluster #{name}", :green)}"
        else
          ui.error "Cluster name provided does not exist: #{name}"
        end
      end

    end
  end
end
