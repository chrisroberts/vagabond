#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module SSH

      def ssh(name, cmd=nil)
        node = load_node(name)
        if(options[:daemon] && cmd.nil?)
          ui.error 'Cannot provide ssh connection when Vagabond is daemonized!'
          raise VagabondErrors::InvalidRequest('Unsupported action in daemon mode')
        end
        if(node.exists?)
          if(node.running?)
            ui.info "#{ui.color('Vagabond:', :bold)} SSH connect to: #{ui.color(name, :cyan)}"
            command = ["#{sudo}ssh root@#{node.address} -i #{Settings[:ssh_key]} -oStrictHostKeyChecking=no"]
            if(cmd)
              command << "\"#{cmd}\"" if cmd # TODO: Fix this with shellwords. Can we with shellout behavior?
              ssh_command = build_command(command.join(' '), :live_stream => ui.live_stream)
              ssh_command.run_command
              unless(ssh_command.exitstatus == 0)
                ui.error "Command failed! (#{cmd})"
                raise VagabondErrors::CommandFailed.new(cmd)
              end
            else
              # dump out to allow ssh connect
              exec command.join(' ')
            end
          else
            ui.error "Node not running: #{name}"
            raise VagabondErrors::NodeNotRunning.new(name)
          end
        else
          ui.error "Node not created: #{name}"
          raise VagabondErrors::NodeNotCreated.new(name)
        end
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::SSH)
