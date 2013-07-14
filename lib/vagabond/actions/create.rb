#encoding: utf-8
require 'elecksee/ephemeral'

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
        elsif(!Vagabond::BASE_TEMPLATES.include?(tmpl))
          ui.fatal "Template requested for node does not exist: #{tmpl}"
          raise VagabondError::InvalidTemplate.new(tmpl)
        end
        unless(config[:device])
          config[:directory] = true
        end
        config[:daemon] = true
        config[:original] = tmpl
        config[:bind] = File.expand_path(vagabondfile.store_directory)
        ephemeral = Lxc::Ephemeral.new(config)
        ephemeral.start!(:fork)
        e_name = ephemeral.name
        @internal_config[mappings_key][name] = e_name
        @internal_config.save
        @lxc = Lxc.new(e_name)
      end

    end
  end
end
