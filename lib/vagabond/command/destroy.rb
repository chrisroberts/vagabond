#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Destroy node
    class Destroy < Command

      # Set for serial execution
      def initialize(*_)
        super
        @serial = true
      end

      # Destroy node
      def run!
        arguments.each do |name|
          unless(node(name).exists?)
            ui.warn "Node does not currently exist: #{name} (performing no tasks)"
          else
            run_action "Destroying #{ui.color(name, COLORS[:destroy])}" do
              node(name).destroy!
              nil
            end
            run_callbacks(node(name))
          end
        end
      end

    end
  end
end
