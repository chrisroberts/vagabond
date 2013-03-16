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
        tmpl = config[:template]
        if(internal_config[:template_mappings].keys.include?(tmpl))
          tmpl = internal_config[:template_mappings][tmpl]
        elsif(!BASE_TEMPLATES.include?(tmpl))
          ui.fatal "Template requested for node does not exist: #{tmpl}"
          exit EXIT_CODES[:invalid_template]
        end
        com = "#{sudo}lxc-start-ephemeral -d -o #{tmpl}"
        debug(com)
        c = Mixlib::ShellOut.new("#{com} && sleep 3", :live_stream => Config[:debug])
        c.run_command
        e_name = c.stdout.split("\n").last.split(' ').last.strip
        @internal_config[:mappings][name] = e_name
        @internal_config.save
        @lxc = Lxc.new(e_name)
      end

    end
  end
end
