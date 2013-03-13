module Vagabond
  module Actions
    module Status
      def status
        ui.info ui.color("Vagabond node status:\n", :bold)
        if(name)
          status_for(name)
        else
          (Array(vagabondfile[:boxes].keys) | Array(internal_config[:mappings].keys)).sort.each do |n|
            status_for(n)
          end
        end
      end

      private

      def status_for(c_name)
        m_name = internal_config[:mappings][c_name]
        state = nil
        status = []
        if(Lxc.exists?(m_name))
          @lxc = Lxc.new(m_name) unless lxc.name == m_name
          info = Lxc.info(m_name)
          state = info[:state]
          status << "PID: #{info[:pid] == -1 ? 'N/A' : info[:pid]}"
          status << "Address: #{lxc.container_ip || 'unknown'}"
          status << "\n"
        end
        case state
        when :running
          color = :green
        when :frozen
          color = :blue
        when :stopped
          color = :yellow
        else
          color = :red
        end
        ui.info ui.color("  #{c_name}: #{state || "Not currently created\n"}", color)
        unless(status.empty?)
          ui.info(status.map{|s| "    #{s}"}.join("\n").chomp)
        end
      end
    end
  end
end
