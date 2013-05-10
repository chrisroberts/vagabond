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
        node = Chef::Node.from_file(
          File.join(
            File.dirname(__FILE__),
            '../cookbooks/vagabond/attributes/default.rb'
          )
        )
        nodes = {}
        node[:vagabond][:bases].keys.each do |template|
          answer = ui.ask("Include template: #{template} (Y/N):")
          if(answer == 'y')
            node[template.gsub('_', '').to_sym] = {
              :template => template,
              :run_list => []
            }
          end
        end
        {
          :nodes => nodes,
          :local_chef_server => {
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
        ui.info "Re-running chef-solo with base containers specified by generated Vagabondfile"
        @internal_config.run_solo
      end
    end
  end
end