module Vagabond
  module Actions
    module Cluster
      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _cluster_options
                [[:auto_provision, :type => :boolean, :desc => 'Automatically provision nodes', :default => true],
                 [:delay, :type => :numeric, :desc => 'Add delay between provisions (helpful for search)', :default => 0]]
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
            # Reload so we get proper values
            @internal_config.load_existing
          end
          clr.each do |n|
            @name = n
            @config = @vagabondfile[:boxes][name]
            @lxc = Lxc.new(@internal_config[mappings_key][name] || '____nonreal____')
            _up
            if(options[:delay].to_i > 0 && n != clr.last)
              ui.warn "Delay requested between node processing. Sleeping for #{options[:delay].to_i} seconds."
              sleep(options[:delay].to_i)
            end
          end
          ui.info "  -> #{ui.color("Built cluster #{name}", :green)}"
        else
          ui.error "Cluster name provided does not exist: #{name}"
        end
      end

    end
  end
end
