#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Start

      def start(name)
        node = load_node(name)
        ui.info "#{ui.color('Vagabond:', :bold)} Starting node: #{ui.color(name, :green)}"
        node.start
        ui.info ui.color('  -> STARTED', :green)
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Start)
