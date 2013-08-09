#encoding: utf-8
module Vagabond
  module Actions
    module Rebuild
      def _rebuild
        name_required!
        ui.info "#{ui.color('Vagabond:', :bold)} Rebuilding #{ui.color(name, :blue)}"
        add_link(:destroy)
        options[:auto_provision] = true
        add_link(:up)
      end
    end
  end
end
