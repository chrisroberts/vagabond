require 'vagabond'

module Vagabond
  class Node

    attr_reader :name, :internal_name, :config, :interface

    def initialize(name, args={})
      @name = name
      @internal_name = generate_name
      @config = args[:config] || Mash.new
      @interface = NodeInterface.build(args[:driver], internal_name)
      @ui = args[:ui] || Ui.ui || Ui::Cli.new
    end

    # Run command on node
    def run_command(cmd, args={})
    end

    def run_solo(data_directory)
      ui.info "#{ui.color('Vagabond:', :bold)} Provisioning node: #{ui.color(name, :magenta)}"
      interface.available?(:wait => 20)
      result = run_command(
        "chef-solo -c #{File.join(data_directory, 'solo.rb')} -j #{File.join(data_directory, 'dna.json')}",
        :live_stream => stdout
      )
      raise VagabondError::NodeProvisionFailed.new("Failed to provision: #{name}") unless result
    end

    # Helper to allow common access style
    def run_list
      config[:run_list]
    end

    # Return attributes defined for node in JSON form
    # (Use for bootstraps)
    def attributes
      if(config[:attributes])
        if(config[:attributes].is_a?(Hash))
          JSON.dump(config[:attributes])
        else
          config[:attributes].to_s
        end
      end
    end

    # Returns if node exists
    def exists?
    end

    # Returns if node is running
    def running?
    end

    def address
    end

    def state
    end

    def pid
    end


    def create
      ## s
              unless(config[:device])
          config[:directory] = true
        end
        config[:daemon] = true
        config[:original] = tmpl
        config[:bind] = File.expand_path(vagabondfile.store_directory)
        ephemeral = Lxc::Ephemeral.new(config)
        e_name = ephemeral.name
        @internal_config[mappings_key][name] = e_name
        @internal_config.save
        ephemeral.start!(:fork)
        @lxc = Lxc.new(e_name)
        @lxc.wait_for_state(:running)

    end

    def destroy

      end

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

    def start
    end


    def stdout
      $stdout
    end

  end
end
