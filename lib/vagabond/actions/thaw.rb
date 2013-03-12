module Vagabond
  module Actions
    module Thaw
      def thaw
        if(lxc.exists?)
          if(lxc.frozen?)
            ui.info "#{ui.color('Vagabond:', :bold)} Thawing node: #{ui.color(name, :yellow)}"
            lxc.unfreeze
            ui.info ui.color('  -> THAWED!', :yellow)
          else
            ui.error "Node is not currently frozen: #{name}"
          end
        else
          ui.error "Node does not exist: #{name}"
        end
      end
    end
  end
end
