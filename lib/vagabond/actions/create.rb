module Vagabond
  module Actions
    module Create
      def create
        create
      end

      private

      # Lets get this out proper!
      def do_create
        unless(check_existing!)
          @ui.info "LXC: Creating #{name}..."
          com = "#{sudo}lxc-start-ephemeral -d -o #{config[:template]}"
          c = Mixlib::ShellOut.new("#{com} && sleep 3")
          c.run_command
          e_name = c.stdout.split("\n").last.split(' ').last.strip
          @internal_config[:mappings][name] = e_name
          @internal_config.save
          @lxc = Lxc.new(e_name)
          @ui.info "LXC: #{name} has been created!"
        else
          lxc.start unless lxc.running?
        end
      end

    end
  end
end
