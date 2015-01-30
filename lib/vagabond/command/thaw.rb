#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Thaw node
    class Thaw < Command

      # Thaw node
      def run!
        arguments.each do |name|
          unless(node(name).exists?)
            ui.warn "Node does not currently exist: #{name} (performing no tasks)"
          else
            run_action "Thawing #{ui.color(name, :yellow)}" do
              node(name).thaw
              nil
            end
            run_callbacks(node(name))
          end
        end
      end

    end
  end
end
