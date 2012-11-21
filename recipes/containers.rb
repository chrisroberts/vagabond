# create the containers defined in the ['lxc']['containers'] hash

include_recipe "lxc"

node['lxc']['containers'].each do | name, container |
  Chef::Log.info "Creating LXC container name:#{name}"
  lxc_container name do
    container.each do |meth, param|
      self.send(meth, param)
    end
    action :create unless container.has_key?(:action)
    # this is getting refactored out into another recipe eventually
    chef_enabled false
  end
end
