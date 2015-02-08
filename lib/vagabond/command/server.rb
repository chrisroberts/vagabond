require 'vagabond'

module Vagabond
  class Command
    module Server

      autoload :Create, 'vagabond/command/server/create'
      autoload :Destroy, 'vagabond/command/server/destroy'
      autoload :Status, 'vagabond/command/server/status'
      autoload :Upload, 'vagabond/command/server/upload'

    end
  end
end
