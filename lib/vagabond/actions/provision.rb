module Vagabond
  module Actions
    module Provision
      def provision
        if(lxc.exists? && lxc.running?)
          do_provision
        else
          ui.fatal "LXC: Requested container: #{name} has not been created!"
        end
      end

      private

      def do_provision
        @ui.info "LXC: Provisioning #{name}..."
        com = "#{sudo}knife bootstrap #{lxc.container_ip(10, true)} -d chef-full -N #{name} -i /opt/hw-lxc-config/id_rsa "
        com << "--no-host-key-verify --run-list \"#{config[:run_list].join(',')}\" "
        if(config[:environment])
          com << "-E #{config[:environment]}"
        end
        if(Config[:knife_opts])
          com << Conifg[:knife_opts]
        end
        cmd = Mixlib::ShellOut.new(com, :live_stream => STDOUT)
        cmd.run_command
        @ui.info "LXC: Provisioning of #{name} complete!"
      end

    end
  end
end
