module Vagabond

  autoload :Actions, 'vagabond/actions'
  autoload :Commander, 'vagabond/commander'
  autoload :Core, 'vagabond/core'
  autoload :COLORS, 'vagabond/constants'
  autoload :VagabondError, 'vagabond/errors'
  autoload :Helpers, 'vagabond/helpers'
  autoload :InternalConfiguration, 'vagabond/internal_configuration'
  autoload :Kitchen, 'vagabond/kitchen'
  autoload :Layout, 'vagabond/layout'
  autoload :NodeInterface, 'vagabond/node_interface'
  autoload :Node, 'vagabond/node'
  autoload :NotifyMash, 'vagabond/notify_mash'
  autoload :Server, 'vagabond/server'
  autoload :Settings, 'vagabond/settings'
  autoload :Spec, 'vagabond/spec'
  autoload :Ui, 'vagabond/ui'
  autoload :Uploader, 'vagabond/uploader'
  autoload :Vagabondfile, 'vagabond/vagabondfile'
  autoload :Version, 'vagabond/version'

end

autoload :Mash, 'chef/mash'
