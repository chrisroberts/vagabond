# install the server dependencies to run lxc
node[:lxc][:packages].each do |lxcpkg|
  package lxcpkg
end

include_recipe 'lxc::install_dependencies'

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
      :lxc_shutdown_timeout => node[:lxc][:shutdown_timeout]
    }
  )
end

#this just reloads the dnsmasq rules when
service "lxc-net" do
  action :enable
  subscribes :restart, resources("template[/etc/default/lxc]")
end
