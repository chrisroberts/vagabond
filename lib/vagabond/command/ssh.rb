#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # SSH to node or send command via ssh
    class Ssh < Command

      # SSH to node or send command
      def run!
        unless(node(arguments.first).exists?)
          ui.warn "Node does not currently exist: #{arguments.first} (performing no tasks)"
        else
          if(arguments.size == 1)
            run_action "Establishing SSH connection to #{ui.color(arguments.first, :green)}" do
              exec("#{Lxc.sudo}ssh root@#{node(arguments.first).address} -i /opt/hw-lxc-config/id_rsa -oStrictHostKeyChecking=no")
            end
          else
            cmd = arguments.slice(1, arguments.size).join(' ')
            run_action "Sending command \"#{cmd}\" to #{ui.color(arguments.first, :green)}" do
              node(arguments.first).run(cmd)
            end
          end
          run_callbacks(node(name))
        end
      end

    end
  end
end