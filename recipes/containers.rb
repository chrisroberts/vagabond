# create the containers defined in the ['lxc']['containers'] hash

include_recipe "lxc"

node['lxc']['containers'].each do | name, container |
  Chef::Log.info "Creating LXC container name:#{name}"
  lxc_container name do
    action :create
    template container['template'] if container['template']
    # this is getting refactored out into another recipe eventually
    chef_enabled false
  end
end
