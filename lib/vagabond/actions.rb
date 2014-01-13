require 'vagabond'

module Vagabond
  module Actions

    autoload :Cluster, 'vagabond/actions/cluster'
    autoload :Create, 'vagabond/actions/create'
    autoload :Destroy, 'vagabond/actions/destroy'
    autoload :Freeze, 'vagabond/actions/freeze'
    autoload :Init, 'vagabond/actions/init'
    autoload :Provision, 'vagabond/actions/provision'
    autoload :Rebuild, 'vagabond/actions/rebuild'
    autoload :Ssh, 'vagabond/actions/ssh'
    autoload :Start, 'vagabond/actions/start'
    autoload :Status, 'vagabond/actions/status'
    autoload :Thaw, 'vagabond/actions/thaw'
    autoload :Up, 'vagabond/actions/up'

    class << self

      # Array of registered modules
      def modules
        @mods ||= []
      end

      # mod:: Module
      # Register module
      def register(mod)
        modules.push(mod).uniq!
      end

    end
  end
end
