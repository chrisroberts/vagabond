#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Create

      def create(name)
        node = load_node(name)
        if(node.exists?)
          ui.warn "Node already exists: #{name}"
          add_link(:start, name)
        else
          ui.info "#{ui.color('Vagabond:', :bold)} Creating #{ui.color(name, :green)}"
          do_create(node)
          ui.info ui.color('  -> CREATED!', :green)
        end
        true
      end

      private

      def do_create(node)
        template = node.config[:template]
        if(internal_config[:template_mappings].keys.include?(template))
          template = internal_config[:template_mappings][template]
        elsif(!Vagabond::BASE_TEMPLATES.include?(template))
          ui.fatal "Template requested for node does not exist: #{template}"
          raise VagabondError::InvalidTemplate.new(template)
        end
        internal_config[:mappings] = node.internal_name
        internal_config.save
        node.create
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Create)
