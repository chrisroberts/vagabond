require 'vagabond'

module Vagabond
  class Command
    class Spec
      # Run specs on a cluster
      class Cluster < Spec

        # Run specs
        def run!
          if(arguments.size == 1)
            c_name = arguments.first
            ui.info "Running cluster spec on #{ui.color(c_name, :bold)}"
            cluster(c_name).each do |name|
              ui.info "Running cluster spec on node #{ui.color(name, :bold)}"
              apply(node(name))
              ui.info "Cluster spec on node #{ui.color(name, :bold)} is #{ui.color('complete', :green, :bold)}"
            end
            ui.info "Cluster spec on #{ui.color(c_name, :bold)} is #{ui.color('complete', :green, :bold)}"
          end
        end

      end
    end
  end
end
