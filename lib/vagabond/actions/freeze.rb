#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Freeze

      def freeze(name)
        node = load_node(name)
        if(node.exists?)
          ui.info "#{ui.color('Vagabond:', :bold)} Freezing node: #{ui.color(name, :blue)}"
          if(node.running?)
            node.freeze
            ui.info ui.color('  -> FROZEN', :blue)
          else
            ui.error "Node is not currently running: #{name}"
          end
        else
          ui.error "Node not created: #{name}"
        end
      end
    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Freeze)
