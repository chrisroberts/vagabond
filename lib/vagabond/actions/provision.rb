#encoding: utf-8
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
        com = ["bootstrap #{lxc.container_ip(10, true)} -N #{name} -i /opt/hw-lxc-config/id_rsa"]
        com << "--no-host-key-verify --run-list \"#{config[:run_list].join(',')}\""
        if(config[:environment])
          com << "-E #{config[:environment]}"
        end
        if(config[:no_lazy_load])
          no_lazy_load_bootstrap = File.join(File.dirname(__FILE__), '..', 'bootstraps/no_lazy_load.erb')
          com << "--template-file #{no_lazy_load_bootstrap}"
        end
        if(config[:chef_10])
          chef_10_bootstrap = File.join(File.dirname(__FILE__), '..', 'bootstraps/chef_10_compat_config.erb')
          com << "--template-file #{chef_10_bootstrap}"
        end
        if(attributes)
          com << "-j '#{attributes}'"
        end
        cmd = knife_command(com.join(' '), :live_stream => STDOUT, :timeout => 2000)
        # Send the live stream out since people will generally want to
        # know what's happening
        cmd.run_command
        # NOTE: cmd.status.success? won't be valid, so check for FATAL
        # TODO: This isn't really the best check, but should be good
        # enough for now
        unless(cmd.stdout.include?('FATAL: Stacktrace'))
          ui.info ui.color('  -> PROVISIONED', :magenta)
          true
        else
          ui.info ui.color('  -> PROVISION FAILED', :red)
          raise VagabondError::NodeProvisionFailed.new("Failed to provision: #{name}")
        end
      end

    end
  end
end
