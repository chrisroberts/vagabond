module Vagabond
  module Actions
    module Up
      def up
        if(@lxc.exists?)
          ui.warn "Existing container found for: #{name}. Starting..."
          do_start
        else
          do_start
        end
      end

      private

      def do_start
        if(lxc.running?)
          ui.error "LXC: #{name} is already running!"
        else
          do_create
          ui.info "LXC: #{name} has been started!"
          do_provision unless Config[:disable_auto_provision]
        end
      end

    end
  end
end
