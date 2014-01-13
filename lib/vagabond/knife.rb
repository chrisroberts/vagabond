#encoding: utf-8

require 'vagabond'
require 'shellwords'

module Vagabond
  class Knife < Vagabond

    def initialize(*args)
      super
    end

    def install_actions
    end

    # TODO: preserve argv and just sub prefix command and split into
    # command string
    def knife(command, *args)
      command_string = [command, args.map{|s| "'#{s}'"}].flatten.compact.join(' ')
      cmd = knife_command(command_string)
      cmd.run_command
      cmd.error!
    end
  end
end
