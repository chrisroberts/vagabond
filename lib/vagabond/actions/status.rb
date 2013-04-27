module Vagabond
  module Actions
    module Status
      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _status_desc
                if(defined?(Server) && self == Server)
                  ['status', 'Status of server']
                else
                  ['status [NODE]', 'Status of NODE or all nodes']
                end
              end
            end
          end
        end
      end
      
      def _status
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
            names = (Array(vagabondfile[:boxes].keys) | Array(internal_config[mappings_key].keys))
          else
            names = Array(internal_config[mappings_key].keys)
          end
          names.sort.each do |n|
            status += status_for(n)
          end
        end
        puts ui.list(status, :uneven_columns_across, 4)
      end

      private

      def status_for(c_name)
        m_name = internal_config[mappings_key][c_name]
        state = nil
        status = []
        if(Lxc.exists?(m_name))
          @lxc = Lxc.new(m_name) unless lxc.name == m_name
          info = Lxc.info(m_name)
          case info[:state]
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
          status << (info[:state] || 'N/A').to_s
          status << (info[:pid] == -1 ? 'N/A' : info[:pid]).to_s
          status << (lxc.container_ip || 'unknown')
        else
          status << ui.color(c_name, :red)
          status += ['N/A'] * 3
        end
        status
      end
    end
  end
end
