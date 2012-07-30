package 'lxc'

include_recipe 'lxc::install_dependencies'

cookbook_file "/usr/lib/lxc/templates/lxc-ubuntu-hw" do
  source 'lxc-ubuntu-hw'
  mode 0755
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
      :lxc_shutdown_timeout => node[:lxc][:shutdown_timeout]
    }
  )
  # notify?
end

node.set[:omnibus_updater][:cache_omnibus_installer] = true
include_recipe 'omnibus_updater::deb_downloader'
