#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Rebuild

      def rebuild(name)
        node = load_node(name)
        ui.info "#{ui.color('Vagabond:', :bold)} Rebuilding #{ui.color(name, :blue)}"
        run_action(:destroy, name)
        run_action(:up, name, :auto_provision => true)
        ui.info "#{ui.color('Vagabond:', :bold)} Rebuild of #{name} - #{ui.color('COMPLETE', :blue)}"
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Rebuild)
