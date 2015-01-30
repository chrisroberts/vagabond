#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    class Status < Command

      def run!
        if(arguments.empty?)
          ui.info "Node Status:"
          Bogo::Ui::Table.new(ui, self) do
            table(:border => false) do
              row(:header => true) do
                column 'Name', :align => 'left', :width => vagabondfile.nodes.keys.map(&:length).max + 3
                column 'IP', :align => 'center', :width => 20
                column 'State', :align => 'right', :padding => 3, :width => 15
              end
              vagabondfile.nodes.keys.sort.each do |name|
                row do
                  column name, :bold => node(name).exists?
                  column node(name).exists? ? node(name).address : '-'
                  column node(name).exists? ? node(name).state : '-', :color => state_color(node(name).state)
                end
              end
            end
          end.display
        else
          undefined = arguments.find_all do |name|
            local_registry.get(:nodes, name).nil?
          end
          if(undefined.empty?)
            ui.info "Node Status:"
            Bogo::Ui::Table.new(ui, self) do
              table do
                row do
                  column 'Name'
                  column 'State'
                  column 'IP'
                end
                arguments.sort.each do |name|
                  row do
                    column name
                    column node(name).state
                    column node(name).address
                  end
                end
              end
            end.display
          else
            ui.error "Invalid node names provided: #{undefined.sort.join(', ')}"
            raise Error::InvalidName.new
          end
        end
      end

      # @return [String]
      def state_color(state)
        case state.to_s
        when 'running'
          'green'
        when 'frozen'
          'blue'
        else
          'red'
        end
      end

    end
  end
end
