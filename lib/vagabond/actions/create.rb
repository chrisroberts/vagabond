module Vagabond
  module Actions
    module Create
      def create
        if(lxc.exists?)
          ui.warn "Node already exists: #{name}" unless name == 'server'
          start
        else
          ui.info "#{ui.color('Vagabond:', :bold)} Creating #{ui.color(name, :green)}"
          do_create
          ui.info ui.color('  -> CREATED!', :green)
        end
      end

      private

      def do_create
        com = "#{sudo}lxc-start-ephemeral -d -o #{config[:template]}"
        c = Mixlib::ShellOut.new("#{com} && sleep 3")
        c.run_command
        e_name = c.stdout.split("\n").last.split(' ').last.strip
        @internal_config[:mappings][name] = e_name
        @internal_config.save
        @lxc = Lxc.new(e_name)
      end

    end
  end
end
