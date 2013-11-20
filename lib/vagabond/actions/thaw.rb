#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Thaw

      def thaw(name)
        node = load_node(name)
        if(node.exists?)
          if(node.frozen?)
            ui.info "#{ui.color('Vagabond:', :bold)} Thawing node: #{ui.color(name, :yellow)}"
            node.unfreeze
            ui.info ui.color('  -> THAWED!', :yellow)
          else
            ui.error "Node is not currently frozen: #{name}"
            raise VagabondErrors::NodeNotFrozen.new(name)
          end
        else
          ui.error "Node does not exist: #{name}"
          raise VagabondErrors::NodeNotCreated.new(name)
        end
      end
    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Thaw)
