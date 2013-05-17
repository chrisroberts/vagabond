# Fedora allowed? Needs yum and curl to download packages
if node[:lxc][:allowed_types].include?('fedora')
  ['yum', 'curl'].each do |pkg|
    package pkg
  end
end

# OpenSuse allowed? Needs zypper (no package available yet!)
# package 'zypper' if node[:lxc][:allowed_types].include?('opensuse')
raise 'OpenSuse not currently supported' if node[:lxc][:allowed_types].include?('opensuse')

#store a copy of the Omnibus installer for use by the lxc containers
if(node[:omnibus_updater] && node[:omnibus_updater][:cache_omnibus_installer])
  include_recipe 'omnibus_updater::downloader'
end
