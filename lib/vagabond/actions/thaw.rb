module Vagabond
  module Actions
    module Thaw
      def thaw
        if(lxc.frozen?)
          lxc.unfreeze
          ui.info "Container has been thawed: #{name}"
        else
          ui.error "Container #{name} is not currently frozen"
        end
      end
    end
  end
end
