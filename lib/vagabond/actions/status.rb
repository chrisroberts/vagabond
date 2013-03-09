module Vagabond
  module Actions
    module Status
      def status
        if(name)
          status_for(name)
        else
          (Array(vagabondfile[:boxes].keys) | Array(internal_config[:mappings].keys)).sort.each do |n|
            status_for(n)
          end
        end
      end

      def status_for(c_name)
        m_name = internal_config[:mappings][c_name]
        if(Lxc.exists?(m_name))
          info = Lxc.info(m_name)
          status = info[:state].to_s
          if(info[:pid])
            status << " - PID: #{info[:pid]}"
          end
        else
          status = 'does not exist'
        end
        ui.info "Status of #{c_name}: #{status}"
      end
    end
  end
end
