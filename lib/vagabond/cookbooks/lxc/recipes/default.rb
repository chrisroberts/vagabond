# install the server dependencies to run lxc
node[:lxc][:packages].each do |lxcpkg|
  package lxcpkg
end

include_recipe 'lxc::install_dependencies'

directory '/usr/local/bin' do
  recursive true
end

cookbook_file '/usr/local/bin/lxc-awesome-ephemeral' do
  source 'lxc-awesome-ephemeral'
  mode 0755
end

#if the server uses the apt::cacher-client recipe, re-use it
unless Chef::Config[:solo]
  if File.exists?('/etc/apt/apt.conf.d/01proxy')
    query = 'recipes:apt\:\:cacher-ng'
    query += " AND chef_environment:#{node.chef_environment}" if node['apt']['cacher-client']['restrict_environment']
    Chef::Log.debug("apt::cacher-client searching for '#{query}'")
    servers = search(:node, query)
    if servers.length > 0
      Chef::Log.info("apt-cacher-ng server found on #{servers[0]}.")
      node.default[:lxc][:mirror] = "http://#{servers[0]['ipaddress']}:3142/archive.ubuntu.com/ubuntu"
    end
  end
end

template '/etc/default/lxc' do
  source 'default-lxc.erb'
  mode 0644
  variables(
    :config => {
      :lxc_auto => node[:lxc][:auto_start],
      :use_lxc_bridge => node[:lxc][:use_bridge],
      :lxc_bridge => node[:lxc][:bridge],
      :lxc_addr => node[:lxc][:addr],
      :lxc_netmask => node[:lxc][:netmask],
      :lxc_network => node[:lxc][:network],
      :lxc_dhcp_range => node[:lxc][:dhcp_range],
      :lxc_dhcp_max => node[:lxc][:dhcp_max],
      :lxc_shutdown_timeout => node[:lxc][:shutdown_timeout],
      :mirror => node[:lxc][:mirror]
    }
  )
end

# this just reloads the dnsmasq rules when the template is adjusted
service 'lxc-net' do
  action [:enable]
  subscribes :restart, resources("template[/etc/default/lxc]"), :immediately
end

service 'lxc' do
  action [:enable, :start]
end
