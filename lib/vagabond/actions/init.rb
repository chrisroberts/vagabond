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
        vagabond_file = "#{Dir.pwd}/Vagabondfile"
        if File.exists? vagabond_file
          ui.warn "A Vagabondfile already exists, do you want to overwrite it?(Y/N)"
          answer = $stdin.gets.chomp
          return unless answer =~ /[Yy]/
          ui.info "Overwriting existing Vagabondfile"
        end
        File.open(vagabond_file, 'w') do |file|
          require 'pp'
          file.write(dummy_hash.pretty_inspect)
        end
      end
    end
  end
end
