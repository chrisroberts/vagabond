#encoding: utf-8
module Vagabond
  module Actions
    module SSH

      SSH_KEY_BASE = '/opt/hw-lxc-config/id_rsa'

      def _ssh
        name_required!
        if(lxc.exists?)
          if(lxc.running?)
            key_path = setup_key!
            ui.info "#{ui.color('Vagabond:', :bold)} SSH connect to: #{ui.color(name, :cyan)}"
            command = ["#{options[:sudo]}ssh root@#{lxc.container_ip(10, true)} -i #{key_path} -oStrictHostKeyChecking=no"]
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

      def setup_key!
        path = "/tmp/.#{ENV['USER']}_id_rsa"
        unless(File.exists?(path))
          [
            "cp #{SSH_KEY_BASE} #{path}",
            "chown #{ENV['USER']} #{path}",
            "chmod 600 #{path}"
          ].each do com
            cmd = build_command(com, :sudo => true)
            cmd.run_command
            cmd.error!
          end
        end
        path
      end
    end
  end
end
