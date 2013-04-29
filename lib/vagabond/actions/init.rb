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
      end

      def _init
        do_init
      end

      private

      def do_init
        dummy_hash = {
          :nodes => {
            :precise => {
              :template => 'ubuntu_1204',
              :run_list => []
            },
            :centos6 => {
              :template => 'centos',
              :run_list => []
            }
          },
          :local_chef_server => {
            :enabled => false,
            :auto_upload => true
          },
          :sudo => true
        }
        bind_path = File.expand_path(File.dirname(vagabondfile.store_path))
        File.open(bind_path, 'w') do |file|
          file.write(dummy_hash)
        end
    end
  end
end
