require 'vagabond'

module Vagabond
  class Command
    # Run specs
    class Spec < Command

      autoload :Cluster, 'vagabond/command/spec/cluster'
      autoload :Init, 'vagabond/command/spec/init'
      autoload :Node, 'vagabond/command/spec/node'

      # @return [String] path to spec directory
      def spec_directory
        File.join(vagabondfile.directory, 'spec')
      end

      # Apply specs against provided node
      #
      # @param node [Vagabond::Node]
      # @return [TrueClass]
      def apply(node)
        ui.info "Running specs on node #{ui.color(node.name, :bold)}"
        specs_for(node).each do |spec_path|
          ui.info "Running spec #{spec_path}"
          host_command("rspec #{spec_path}",
            :stream => true,
            :cwd => vagabondfile.directory,
            :environment => {
              'VAGABOND_TEST_HOST' => node.address
            }
          )
          ui.info "Completed spec #{ui.color(spec_path, :green, :bold)}"
        end
        ui.info "Completed specs on node #{ui.color(node.name, :bold, :green)}"
        true
      end

      # @return [Array<String>] paths of specs
      def specs_for(node)
        specs = node.configuration.fetch(:chef, :run_list, []).map do |item|
          if(item.start_with?('recipe'))
            r_name = item.sub('recipe[', '').sub(']', '')
            r_name = item.split('@').first
            c_name, r_name = r_name.split('::')
            r_name = 'default' unless r_name
            Dir.glob(File.join(spec_directory, 'recipes', c_name, r_name, '*.rb'))
          else # Role
            r_name = item.sub('role[', '').sub(']', '')
            Dir.glob(File.join(spec_directory, 'roles', r_name, '*.rb'))
          end
        end.flatten.compact
        specs += node.configuration.fetch(:specs, :custom, []).map do |item|
          Dir.glob(File.join(spec_directory, 'custom', *item.split('::'), '*.rb'))
        end.flatten.compact
        specs
      end

    end
  end
end
