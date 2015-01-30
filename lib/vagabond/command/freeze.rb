#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Freeze node
    class Freeze < Command

      # Freeze node
      def run!
        arguments.each do |name|
          unless(node(name).exists?)
            ui.warn "Node does not currently exist: #{name} (performing no tasks)"
          else
            run_action "Freezing #{ui.color(name, :blue)}" do
              node(name).freeze
              nil
            end
            run_callbacks(node(name))
          end
        end
      end

    end
  end
end
