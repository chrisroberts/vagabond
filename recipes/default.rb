package 'lxc'

cookbook_file "/usr/lib/lxc/templates/lxc-ubuntu-hw" do
  source 'lxc-ubuntu-hw'
  mode 0755
end
