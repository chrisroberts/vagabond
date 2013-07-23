#encoding: utf-8
module Vagabond
  module Actions
    module Cluster
      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _cluster_options
                [[
                    :auto_provision, :type => :boolean,
                    :desc => 'Automatically provision nodes', :default => true
                  ],
                  [
                    :delay, :type => :numeric, :default => 0,
                    :desc => 'Add delay between provisions (helpful for indexing)'
                  ],
                  [
                    :parallel, :type => :boolean, :default => false,
                    :desc => 'Build nodes in parallel'
                  ]
                ]
              end
            end
          end
        end
      end

      def cluster_validate?
        false
      end

      def _cluster
        clr = vagabondfile[:clusters][name] if vagabondfile[:clusters]
        if(clr)
          ui.info "#{ui.color('Vagabond:', :bold)} Building cluster - #{ui.color(name, :green)}"
          if(vagabondfile.local_chef_server?)
            require 'vagabond/server'
            srv = ::Vagabond::Server.new
            srv.options = options.dup
            srv.options[:auto_provision] = true
            srv.send(:setup, 'up')
            srv.execute
            # Reload so we get proper values
            load_configurations
          end
          cluster_instances = clr.map do |n|
            ui.info "Building #{n} for cluster!"
            v_inst = Vagabond.new
            v_inst.options = options.dup
            v_inst.send(:setup, 'up', n, :ui => ui)
            v_inst.execute
            if(options[:delay].to_i > 0 && n != clr.last)
              ui.warn "Delay requested between node processing. Sleeping for #{options[:delay].to_i} seconds."
              sleep(options[:delay].to_i)
            end
            v_inst
          end
          if(options[:parallel])
            ui.info "Waiting for parallel completes!"
            cluster_instances.map do |inst|
              inst.wait_for_completion
            end
          end
          failed = cluster_instances.map{|i|i.send(:tasks)}.map(&:values).flatten.detect do |hash|
            hash[:result] == false
          end
          result = failed ? ['FAILED', :red, :bold] : ['SUCCESS', :green, :bold]
          ui.info "\nCluster build #{name}: #{ui.color(*result)}"
          cluster_instances.each do |inst|
            failed = inst.send(:tasks).values.flatten.detect do |hash|
              hash[:result] == false
            end
            result = failed ? ['FAILED', :red, :bold] : ['SUCCESS', :green, :bold]
            ui.info "  -> #{inst.name}: #{ui.color(*result)}"
          end
        else
          ui.error "Cluster name provided does not exist: #{name}"
        end
      end

    end
  end
end
