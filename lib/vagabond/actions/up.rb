module Vagabond
  module Actions
    module Up
      def up
        if(lxc.exists?)
          if(lxc.running?)
            ui.error "Node already exists and is running: #{name}"
          else
            ui.warn "Node already exists: #{name}."
            do_provision unless Config[:disable_auto_provision]
          end
        else
          do_create
        end
        do_provision unless Config[:disable_auto_provision]
      end

    end
  end
end
