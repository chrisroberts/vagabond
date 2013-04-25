module Vagabond
  module Actions
    module Destroy

      def _destroy
        name_required!
        [name, @leftover_args].flatten.compact.each do |n|
          @name = n
          load_configurations
          if(lxc.exists?)
            ui.info "#{ui.color('Vagabond:', :bold)} Destroying node: #{ui.color(name, :red)}"
            do_destroy
            ui.info ui.color('  -> DESTROYED', :red)
          else
            ui.error "Node not created: #{name}"
          end
        end
      end

      private

      def do_destroy
        lxc.shutdown if lxc.running?
        com = "#{options[:sudo]}lxc-destroy -n #{lxc.name}"
        debug(com)
        cmd = Mixlib::ShellOut.new(com, :live_stream => options[:debug])
        cmd.run_command
        cmd.error!
        force_umount_if_required!
        internal_config[mappings_key].delete(name)
        internal_config.save
      end

      def force_umount_if_required!
        mount = %x{mount}.split("\n").find_all do |line|
          line.include?(lxc.name)
        end
        unless(mount.empty?)
          ui.info ui.color('  -> Failed to unmount some resources. Forcing manually.', :yellow)
          %w(rootfs ephemeralbind).each do |mnt|
            com = "#{options[:sudo]}umount /var/lib/lxc/#{lxc.name}/#{mnt}"
            debug(com)
            cmd = Mixlib::ShellOut.new(com, :live_stream => options[:debug])
            cmd.run_command
            com = "#{options[:sudo]}lxc-destroy -n #{lxc.name}"
            debug(com)
            cmd = Mixlib::ShellOut.new(com, :live_stream => options[:debug])
            cmd.run_command
            cmd.error!
          end
          # check for tmpfs and umount too
          tmp = mount.detect{|x|x.include?('rootfs')}.scan(%r{upperdir=[^,]+}).first.to_s.split('=').last
          if(tmp)
            com = "#{options[:sudo]}umount #{tmp}"
            debug(com)
            cmd = Mixlib::ShellOut.new(com, :live_stream => options[:debug])
            cmd.run_command
          end
        end
      end
    end
  end
end
