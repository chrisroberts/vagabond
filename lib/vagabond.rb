require 'elecksee'
require 'bogo-cli'

module Vagabond

  autoload :Command, 'vagabond/command'
  autoload :Error, 'vagabond/errors'
  autoload :Node, 'vagabond/node'
  autoload :Registry, 'vagabond/registry'
  autoload :Utils, 'vagabond/utils'
  autoload :Vagabondfile, 'vagabond/vagabondfile'

end

require 'vagabond/version'
require 'vagabond/constants'

Lxc.use_sudo = system('which rvmsudo > /dev/null') ? 'rvmsudo' : true
Lxc.default_ssh_key = File.join(Dir.home, '.ssh/lxc_container_rsa')
