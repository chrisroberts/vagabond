require 'vagabond'

module Vagabond
  class Command
    class Spec
      class Init < Spec

        # Set for serial execution
        def initialize(*_)
          super
          @serial = true
        end

        # Create node
        def run!
          ui.info 'Initializing spec configuration'
          init_directories
          init_files
          ui.info 'Spec configuration complete!'
        end

        protected

        # Create required directories for spec setup
        #
        # @return [Array<String>] directory paths
        def init_directories
          %w(role recipe).map do |leaf|
            FileUtils.mkdir_p(File.join(spec_directory, leaf))
          end
        end

        # @return [Array<String>] file paths
        def init_files
          path = File.join(spec_directory, 'spec_helper.rb')
          if(File.exists?(path))
            ui.confirm 'Overwrite existing `spec_helper.rb` file'
          end
          File.open(path, 'w+') do |file|
            file.puts spec_file_content
          end
          [path]
        end

        # @return [String] content for spec_helper.rb
        def spec_file_content
          output = <<-EOF
require 'serverspec'

set :backend, :ssh

RSpec.configure do |c|
  c.before do
    c.host = ENV['VAGABOND_TEST_HOST']
    c.ssh_options = {:user => 'root'}
    c.ssh_options[:keys] = ['#{vagabondfile.ssh_key}']
  end
end
EOF

        end

      end
    end
  end
end
