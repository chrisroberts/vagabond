#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Status

      def status(name)
        node = load_node(name) if name
        status = [
          ui.color('Name', :bold),
          ui.color('State', :bold),
          ui.color('PID', :bold),
          ui.color('IP', :bold)
        ]
        if(name)
          status += status_for(name)
        else
          if(self.is_a?(Vagabond))
            names = (Array(vagabondfile[:nodes].keys) | Array(internal_config[:mappings].keys))
          else
            names = Array(internal_config[:mappings].keys)
          end
          names.sort.each do |n|
            status += status_for(n)
          end
        end
        ui.info ui.list(status, :uneven_columns_across, 4)
      end

      private

      def status_for(name)
        node = load_node(name)
        begin
          node = load_node(name)
        rescue
          node = nil
        end
        state = nil
        status = []
        if(node && node.exists?)
          case node.state
          when :running
            color = :green
          when :frozen
            color = :blue
          when :stopped
            color = :yellow
          else
            color = :red
          end
          status << ui.color(c_name, color)
          status << (node.state || 'N/A').to_s
          status << (node.pid == -1 ? 'N/A' : node.pid).to_s
          status << (node.address || 'unknown')
        else
          status << ui.color(name, :red)
          status += ['N/A'] * 3
        end
        status
      end
    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Status)
