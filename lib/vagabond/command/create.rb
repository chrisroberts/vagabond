#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Create new node
    class Create < Command

      # Set for serial execution
      def initialize(*_)
        super
        @serial = true
      end

      # Create node
      def run!
        arguments.each do |name|
          if(node(name).exists?)
            ui.warn "Node already exists: #{name} (performing no tasks)"
          else
            run_action "Creating #{ui.color(name, COLORS[:create])}" do
              node(name).create!
              nil
            end
            run_callbacks(node(name))
          end
        end
      end

    end
  end
end
