package 'lxc'

cookbook_file "/usr/lib/lxc/templates/lxc-ubuntu-hw" do
  source 'lxc-ubuntu-hw'
  mode 0755
end

node.set[:omnibus_updater][:cache_omnibus_installer] = true
include_recipe 'omnibus_updater::deb_downloader'
