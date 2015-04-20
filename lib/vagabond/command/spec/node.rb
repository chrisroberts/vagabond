require 'vagabond'

module Vagabond
  class Command
    class Spec
      # Run specs on single node
      class Node < Spec

        # Create node
        def run!
          arguments.each do |name|
            ui.info "Running single node spec on #{ui.color(name, :bold)}"
            apply(node(name))
            ui.info "Single node spec on #{ui.color(name, :bold)} is #{ui.color('complete', :green, :bold)}"
          end
        end

      end
    end
  end
end
