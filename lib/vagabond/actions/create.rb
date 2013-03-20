module Vagabond
  module Actions
    module Create
      def _create
        name_required!
        if(lxc.exists?)
          ui.warn "Node already exists: #{name}" unless name == 'server'
          _start
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
        bind_path = File.expand_path(File.dirname(vagabondfile.path))
        com = "#{sudo}lxc-start-ephemeral -d -b #{bind_path} -o #{tmpl}"
        debug(com)
        c = Mixlib::ShellOut.new("#{com} && sleep 3", :live_stream => options[:debug])
        c.run_command
        e_name = c.stdout.split("\n").last.split(' ').last.strip
        @internal_config[mappings_key][name] = e_name
        @internal_config.save
        @lxc = Lxc.new(e_name)
      end

    end
  end
end
