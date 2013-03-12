module Vagabond
  module Actions
    module Create
      def create
        if(lxc.exists?)
          ui.error "Node already exists: #{name}"
        else
          create
        end
      end

      private

      def do_create
        unless(check_existing!)
          @ui.info "#{ui.color('Vagabond:', :bold)} Creating #{ui.color(name, :green)}"
          com = "#{sudo}lxc-start-ephemeral -d -o #{config[:template]}"
          c = Mixlib::ShellOut.new("#{com} && sleep 3")
          c.run_command
          e_name = c.stdout.split("\n").last.split(' ').last.strip
          @internal_config[:mappings][name] = e_name
          @internal_config.save
          @lxc = Lxc.new(e_name)
          @ui.info ui.color('  -> CREATED!', :green)
        else
          lxc.start unless lxc.running?
        end
      end

    end
  end
end
