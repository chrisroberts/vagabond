module Vagabond
  module Actions
    module Destroy
      def destroy
        ui.info "Destroying instance: #{name}..."
        do_destroy
        ui.info 'Complete!'
      end

      private

      def do_destroy
        lxc.stop if lxc.running?
        com = "#{Config[:sudo]}lxc-destroy -n #{lxc.name}"
        cmd = Mixlib::ShellOut.new(com)
        cmd.run_command
        cmd.error!
        if(cmd.stderr.include?('skipping'))
          ui.warn 'Failed to unmount some resource. Doing so manually'
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
