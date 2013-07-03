#encoding: utf-8
module Vagabond
  module Actions
    module Start

      def _start
        name_required!
        ui.info "#{ui.color('Vagabond:', :bold)} Starting node: #{ui.color(name, :green)}"
        do_start
        ui.info ui.color('  -> STARTED', :green)
      end

      protected
      
      def do_start
        lxc.start
      end
    end
  end
end
