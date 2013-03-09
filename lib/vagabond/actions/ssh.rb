module Vagabond
  module Actions
    module SSH
      def ssh
        if(lxc.running?)
          exec("#{Config[:sudo]}ssh root@#{lxc.container_ip(10, true)} -i /opt/hw-lxc-config/id_rsa -oStrictHostKeyChecking=no")
        else
          ui.error "Container #{name} is not currently running"
        end
      end
    end
  end
end
