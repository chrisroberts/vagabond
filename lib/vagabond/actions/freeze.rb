module Vagabond
  module Actions
    module Freeze
      def freeze
        if(lxc.exists?)
          ui.info "#{ui.color('Vagabond:', :bold)} Freezing node: #{ui.color(name, :blue)}"
          if(lxc.running?)
            lxc.freeze
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
