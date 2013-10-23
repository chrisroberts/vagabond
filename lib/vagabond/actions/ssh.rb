#encoding: utf-8
module Vagabond
  module Actions
    module SSH

      def _ssh
        name_required!
        if(lxc.exists?)
          if(lxc.running?)
            key_path = setup_key!
            ui.info "#{ui.color('Vagabond:', :bold)} SSH connect to: #{ui.color(name, :cyan)}"
            command = ["#{options[:sudo]}ssh root@#{lxc.container_ip(10, true)} -i #{Settings[:ssh_key]} -oStrictHostKeyChecking=no"]
            if(@leftover_args)
              command << "\"#{@leftover_args.join(' ')}\""
            end
            exec command.join(' ')
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
