module Vagabond
  module Actions
    module Freeze
      def freeze
        if(lxc.running?)
          lxc.freeze
          ui.info "Container has been frozen: #{name}"
        else
          ui.error "Container #{name} is not currently running"
        end
      end
    end
  end
end
