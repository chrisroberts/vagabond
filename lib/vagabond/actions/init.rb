#encoding: utf-8
module Vagabond
  module Actions
    module Init
      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _init_desc
                ['init', 'initialize the Vagabondfile and setup LXC if needed.']
              end
            end
          end
        end
      end

      def _init
        do_init
      end

      private

      def empty_vagabondfile_hash
        node = internal_configuration.cookbook_attributes(:vagabond)
        nodes = {}
        node[:vagabond][:bases].keys.each do |template|
          answer = nil
          until(%w(n y).include?(answer))
            answer = ui.ask_question("Include template: #{template} ", :default => 'y').downcase
          end
          if(answer.downcase == 'y')
            ui.info "Enabling template #{template} with node name #{template.gsub('_', '')}"
            nodes[template.gsub('_', '').to_sym] = {
              :template => template,
              :run_list => []
            }
          else
            ui.warn "Skipping instance for template #{template}"
          end
        end
        {
          :nodes => nodes,
          :clusters => {},
          :local_chef_server => {
            :zero => false,
            :berkshelf => false,
            :librarian => false,
            :enabled => false,
            :auto_upload => true
          },
          :sudo => true
        }
      end
        
      def do_init
        if(File.exists?(vagabondfile.path))
          ui.confirm('Overwrite existing Vagabondfile', true)
          ui.info 'Overwriting existing Vagabondfile'
        end
        require 'pp'
        File.open(vagabondfile.path, 'w') do |file|
          file.write(empty_vagabondfile_hash.pretty_inspect)
        end
        @vagabondfile.load_configuration!
        @internal_config = InternalConfiguration.new(@vagabondfile, ui, options)
      end
    end
  end
end
