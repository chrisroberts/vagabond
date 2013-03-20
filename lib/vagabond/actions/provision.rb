module Vagabond
  module Actions
    module Provision
      def _provision
        name_required!
        if(lxc.exists?)
          if(lxc.running?)
            do_provision
          else
            ui.error "Node is not currently running: #{name}"
          end
        else
          ui.error "Node not created: #{name}"
        end
      end
      
      private

      def do_provision
        ui.info "#{ui.color('Vagabond:', :bold)} Provisioning node: #{ui.color(name, :magenta)}"
        com = "sudo knife bootstrap #{lxc.container_ip(10, true)} -d chef-full -N #{name} -i /opt/hw-lxc-config/id_rsa "
        com << "--no-host-key-verify --run-list \"#{config[:run_list].join(',')}\" "
        if(config[:environment])
          com << "-E #{config[:environment]}"
        end
        if(options[:knife_opts])
          com << options[:knife_opts]
        end
        debug(com)
        # Send the live stream out since people will generally want to
        # know what's happening
        cmd = Mixlib::ShellOut.new(com, :live_stream => STDOUT)
        cmd.run_command
        # NOTE: cmd.status.success? won't be valid, so check for FATAL
        unless(cmd.stdout.split("\n").last.to_s.include?('FATAL'))
          ui.info ui.color('  -> PROVISIONED', :magenta)
          true
        else
          ui.info ui.color('  -> PROVISION FAILED', :red)
          false
        end
      end

    end
  end
end
