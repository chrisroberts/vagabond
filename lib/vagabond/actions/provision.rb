#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Provision

      def provision(name)
        node = load_node(name)
        if(node.exists?)
          if(node.running?)
            do_provision
          else
            ui.error "Node is not currently running: #{name}"
            raise NodeNotRunning.new(name)
          end
        else
          ui.error "Node not created: #{name}"
          raise NodeNotCreated.new(name)
        end
      end

      private

      def do_provision(node, opts={})
        ui.info "#{ui.color('Vagabond:', :bold)} Provisioning node: #{ui.color(node.name, :magenta)}"
        bootstrap = ["bootstrap #{node.address} -N #{node.name} -i #{Settings[:ssh_key]}"]
        bootstrap << "--no-host-key-verify --run-list \"#{node.config[:run_list].join(', ')}\""
        if(node.config[:environment])
          bootstrap << "-E #{config[:environment]}"
        end
        if(node.config[:no_lazy_load])
          no_lazy_load_bootstrap = File.join(File.dirname(__FILE__), '..', 'bootstraps/no_lazy_load.erb')
          bootstrap << "--template-file #{no_lazy_load_bootstrap}"
        elsif(node.config[:chef_10])
          chef_10_bootstrap = File.join(File.dirname(__FILE__), '..', 'bootstraps/chef_10_compat_config.erb')
          bootstrap << "--template-file #{chef_10_bootstrap}"
        elsif(opts[:custom_bootstrap])
          bootstrap << "--template-file #{opts[:custom_bootstrap]}"
        end
        if(node.attributes)
          bootstrap << "-j '#{attributes}'"
        end
        if(opts[:extras])
          bootstrap += Array(opts[:extras]).flatten.compact
        end
        cmd = knife_command(bootstrap.join(' '), :live_stream => ui.live_stream, :timeout => 2000)
        cmd.run_command
        unless(cmd.stdout.include?('FATAL: Stacktrace'))
          ui.info ui.color('  -> PROVISIONED', :magenta)
          true
        else
          ui.info ui.color('  -> PROVISION FAILED', :red)
          raise VagabondError::NodeProvisionFailed.new("Failed to provision: #{name}")
        end
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Provision)
