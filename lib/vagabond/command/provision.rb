#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Provision node
    class Provision < Command

      # Provision node
      def run!
        arguments.each do |name|
          unless(node(name).exists?)
            ui.warn "Node does not currently exist: #{name} (performing no tasks)"
          else
            run_action "Provisioning #{ui.color(name, COLORS[:yellow])}" do
              provision(node(name))
              nil
            end
            run_callbacks(node(name))
          end
        end
      end

      # Provision the given node
      #
      # @param node [Node]
      # @return [TrueClass, FalseClass]
      def provision(node)
        case node.configuration[:provision_via].to_s
        else
          provision_via_chef(node)
        end
      end

      # Provision node via Chef
      #
      # @param node [Node]
      # @return [TrueClass, FalseClass]
      def provision_via_chef(node)
        if(server_node?(node))
          provision_chef_server(node)
        else
          if(server_node)
            provision_chef_node(node)
          else
            raise Error::NodeNotRunning.new('No Chef server instance located to provision against!')
          end
        end
      end

      # @return [TrueClass, FalseClass] node is Chef server
      def server_node?(node)
        node.name == 'server' && node.classification.nil?
      end

      # Provision as chef server node
      #
      # @param node [Node]
      # @return [TrueClass]
      def provision_chef_server(node)

      end

      # Provision as chef client node
      #
      # @return [TrueClass]
      def provision_chef_node(node)
        bootstrap = node.configuration[:chef].to_smash # convert to ensure dup
        cmd = [
          "knife bootstrap #{node.address} -N #{[node.classification, node.name].compact.join('-')}",
          "-i #{vagabondfile.ssh_key} -x #{vagabondfile.ssh_user} --no-host-verify-key"
        ]
        if(bootstrap[:run_list])
          cmd << "--run-list \"#{bootstrap.delete(:run_list).join(', ')}\""
        end
        if(bootstrap.delete(:no_lazy_load))
          cmd << "--template-file #{File.join(File.dirname(__FILE__), '..', 'bootstraps/no_lazy_load.erb')}"
        elsif(bootstrap.delete(:chef_10))
          cmd << "--template-file #{File.join(File.dirname(__FILE__), '..', 'bootstraps/chef_10_compat_config.erb')}"
        elsif(bootstrap[:bootstrap_template])
          cmd << "--template-file #{bootstrap.delete(:bootstrap_template)}"
        end
        if(bootstrap[:attributes])
          cmd << "-j '#{MultiJson.dump(bootstrap.delete[:attributes])}'"
        end
        bootstrap.each do |flag, value|
          cmd << "--#{flag.gsub('_', '-')} '#{value}'"
        end
        host_command(cmd.join(' '))
        true
      end

    end
  end
end
