module Vagabond
  module Actions
    module Destroy
      def destroy
        if(lxc.exists?)
          ui.info "#{ui.color('Vagabond:', :bold)} Destroying node: #{ui.color(name, :red)}"
          do_destroy
          ui.info ui.color('  -> DESTROYED', :red)
        else
          ui.error "Node not created: #{name}"
        end
      end

      private

      def do_destroy
        lxc.stop if lxc.running?
        com = "#{Config[:sudo]}lxc-destroy -n #{lxc.name}"
        cmd = Mixlib::ShellOut.new(com)
        cmd.run_command
        cmd.error!
        if(cmd.stderr.include?('skipping'))
          ui.info ui.color('  -> Failed to unmount some resources. Forcing manually.', :yellow)
          %w(rootfs ephemeralbind).each do |mnt|
            cmd = Mixlib::ShellOut.new("#{Config[:sudo]}umount /var/lib/lxc/#{lxc.name}/#{mnt}")
            cmd.run_command
            cmd = Mixlib::ShellOut.new("#{Config[:sudo]}lxc-destroy -n #{lxc.name}")
            cmd.run_command
            cmd.error!
          end
        end
      end
    end
  end
end
