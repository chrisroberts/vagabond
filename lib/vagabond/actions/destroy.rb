#encoding: utf-8
module Vagabond
  module Actions
    module Destroy

      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _destroy_options
                [
                  [
                    :cluster, :type => :boolean,
                    :desc => 'Destroy cluster of nodes with provided name', :default => false
                  ]
                ]
              end
            end
          end
        end
      end

      def destroy_validate?
        !options[:cluster]
      end
      
      def _destroy
        name_required!
        @destroyed ||= []
        if(options[:cluster])
          @cluster_name = name
          @to_destroy = vagabondfile[:clusters][name] if vagabondfile[:clusters]
          if(@to_destroy)
            ui.info "#{ui.color('Vagabond:', :bold)} Destroying cluster - #{ui.color(name, :red)}"
          else
            ui.error "Cluster name provided does not exist: #{name}"
            @to_destroy = []
          end
        else
          @to_destroy = [name, @leftover_args].flatten.compact
        end
        remain = @to_destroy - @destroyed
        @name = remain.shift
        configure
        if(lxc.exists?)
          ui.info "#{ui.color('Vagabond:', :bold)} Destroying node: #{ui.color(name, :red)}"
          do_destroy
          ui.info ui.color('  -> DESTROYED', :red)
        else
          ui.error "Node not created: #{name}"
        end
        @destroyed << @name
        if(@destroyed.size == @to_destroy.size)
          if(@cluster_name)
            @name = @cluster_name
            configure
          end
        else
          add_link(:destroy)
        end
      end

      private

      def do_destroy
        lxc.shutdown if lxc.running?
        ui.info 'Waiting for graceful shutdown and cleanup...'
        5.times do
          break unless lxc.exists?
          sleep(1)
        end
        if(lxc.exists?)
          com = "#{options[:sudo]}lxc-destroy -n #{lxc.name}"
          debug(com)
          cmd = Mixlib::ShellOut.new(com, :live_stream => options[:debug])
          cmd.run_command
          force_umount_if_required!
        end
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
