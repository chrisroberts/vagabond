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
        when false
        else
          provision_via_chef(node)
        end
      end

      # Provision node via Chef
      #
      # @param node [Node]
      # @return [TrueClass, FalseClass]
      def provision_via_chef(node)
        if(node.server?)
          provision_chef_server(node)
        else
          if(server_node)
            provision_chef_node(node)
          else
            raise Error::NodeNotRunning.new('No Chef server instance located to provision against!')
          end
        end
      end

      # Provision as chef server node
      #
      # @param node [Node]
      # @return [TrueClass]
      def provision_chef_server(node)
        bootstrap = node.configuration.fetch(:chef, {}).to_smash
        # ensure cookbook directory is clean
        node.run('rm -rf /var/chef-host/cookbooks')
        node.run('mkdir -p /var/chef-host')
        # link cookbooks
        node.run("ln -s #{File.join(vagabondfile[:global_cache], 'cookbooks')} /var/chef-host/cookbooks")
        cmd = [
          "knife bootstrap #{node.address} -N server",
          "-i #{vagabondfile.ssh_key} -x #{vagabondfile.ssh_user} --no-host-key-verify"
        ]
        template = File.expand_path(
          node.configuration[:zero] ? 'bootstraps/server-zero.erb' : 'bootstraps/server.erb',
          File.dirname(File.dirname(__FILE__))
        )
        cmd << "--template-file #{template}"
        if(bootstrap[:attributes])
          cmd << "-j '#{MultiJson.dump(bootstrap.delete[:attributes])}'"
        end
        bootstrap.each do |flag, value|
          cmd << "--#{flag.gsub('_', '-')} '#{value}'"
        end
        ensure_chef_config!
        host_command(cmd.join(' '))
        true
      end

      # Provision as chef client node
      #
      # @return [TrueClass]
      def provision_chef_node(node)
        server_required!
        bootstrap = node.configuration.fetch(:chef, {}).to_smash # convert to ensure dup
        cmd = "bootstrap #{node.address} -N #{[node.classification, node.name].compact.join('-')} " <<
          "-i #{vagabondfile.ssh_key} -x #{vagabondfile.ssh_user} --no-host-key-verify"
        cmd = cmd.split(' ')
        if(bootstrap[:run_list])
          cmd.push('--run-list').push(bootstrap.delete(:run_list).join(', '))
        end
        if(bootstrap.delete(:no_lazy_load))
          cmd.push('--template-file').push("#{File.join(File.dirname(__FILE__), '..', 'bootstraps/no_lazy_load.erb')}")
        elsif(bootstrap.delete(:chef_10))
          cmd.push('--template-file').push("#{File.join(File.dirname(__FILE__), '..', 'bootstraps/chef_10_compat_config.erb')}")
        elsif(bootstrap[:bootstrap_template])
          cmd.push('--template-file').push(bootstrap.delete(:bootstrap_template))
        end
        if(bootstrap[:attributes])
          cmd.push('-j').push(MultiJson.dump(bootstrap.delete(:attributes)))
        end
        bootstrap.each do |flag, value|
          cmd.push("--#{flag.gsub('_', '-')}").push("'#{value}'")
        end
        ui.puts
        Knife.new(options.merge(:ui => ui), cmd).execute!
        true
      end

      # Check for local knife configuration and if none exists, create
      # a new one with new keys for client and validation
      def ensure_chef_config!
        config_file = File.join(vagabondfile.directory, '.chef', 'knife.rb')
        unless(File.exists?(config_file))
          ui.warn 'No configuration file found for knife!'
          ui.confirm 'Create knife configuration and client/validator pem files'
          FileUtils.mkdir_p(File.dirname(config_file))
          require 'openssl'
          File.open(config_file, 'w') do |file|
            file.puts "node_name '#{ENV['USER']}'"
            file.puts "client_key '#{File.join(File.dirname(config_file), 'client.pem')}'"
            file.puts "validation_client_name 'vagabond-validator'"
            file.puts "validation_key '#{File.join(File.dirname(config_file), 'validation.pem')}'"
          end
          File.open(File.join(File.dirname(config_file), 'client.pem'), 'w') do |file|
            file.write OpenSSL::PKey::RSA.new(2048).export
          end
          FileUtils.chmod(0600, File.join(File.dirname(config_file), 'client.pem'))
          File.open(File.join(File.dirname(config_file), 'validation.pem'), 'w') do |file|
            file.write OpenSSL::PKey::RSA.new(2048).export
          end
          FileUtils.chmod(0600, File.join(File.dirname(config_file), 'validation.pem'))
        end
      end

    end
  end
end
