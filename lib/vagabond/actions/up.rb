module Vagabond
  module Actions
    module Up
      def up
        if(lxc.exists?)
          if(lxc.running?)
            ui.error "Node already exists and is running: #{name}"
          else
            ui.info "#{ui.color('Vagabond:', :bold)} Starting node: #{ui.color(name, :green)}"
            lxc.start
            ui.info ui.color('  -> STARTED', :green)
          end
        else
          create
        end
        do_provision unless Config[:disable_auto_provision]
      end

    end
  end
end
