# Fedora allowed? Need yum
package 'yum' if node[:lxc][:allowed_types].include?('fedora')

# OpenSuse allowed? Needs zypper (no package available yet!)
# package 'zypper' if node[:lxc][:allowed_types].include?('opensuse')
raise 'OpenSuse not currently supported' if node[:lxc][:allowed_types].include?('opensuse')
