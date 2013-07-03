#encoding: utf-8
module Vagabond
  module Actions
    module SSH
      def _ssh
        name_required!
        if(lxc.exists?)
          if(lxc.running?)
            ui.info "#{ui.color('Vagabond:', :bold)} SSH connect to: #{ui.color(name, :cyan)}"
            exec("#{options[:sudo]}ssh root@#{lxc.container_ip(10, true)} -i /opt/hw-lxc-config/id_rsa -oStrictHostKeyChecking=no")
          else
            ui.error "Node not running: #{name}"
          end
        else
          ui.error "Node not created: #{name}"
        end
      end
    end
  end
end
