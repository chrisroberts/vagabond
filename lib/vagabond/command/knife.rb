#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Knife a node
    class Knife < Command

      # Knife that node
      def run!
        server_required!
        ui.info "`knife #{arguments.join(' ')}`:"
        cmd = ['knife', *arguments]
        cmd.push('--server-url').push("https://#{server_node.address}")
        host_command(cmd,
          :stream => true,
          :cwd => options.fetch(:knife_cwd, Dir.pwd)
        )
      end

    end
  end
end
