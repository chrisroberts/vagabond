include_recipe 'lxc'

directory '/etc/knife-lxc' do
  action :create
  mode 0755
end

file '/etc/knife-lxc/config.json' do
  mode 0644
  content(
    JSON.pretty_generate(
      :addresses => {
        :static => node[:lxc][:knife][:static_ips],
        :range => node[:lxc][:knife][:static_range]
      }
    )
  )
end

package 'bridge-utils'

execute "restart networking" do
  command "service networking restart"
  action :nothing
end

# Setup bridge. Should be done differently, but lazy up front,
# optimize after working
ruby_block 'add bridge' do
  block do
    contents = File.readlines('/etc/network/interfaces')
    idx = contents.find_index do |line|
      line.include?('iface') && line.include?(node[:lxc][:knife][:device_to_bridge])
    end
    if(idx)
      removed = []
      remains = contents.slice(idx + 1, contents.size)
      removed.push(remains.shift) while !remains.empty? && remains.first.to_s =~ /^\s/
      contents.slice!(idx, removed.size + 1)
      contents.delete_if{|line| line.include?("auto #{node[:lxc][:knife][:device_to_bridge]}")}
    end
    [
      'auto br0',
      "iface br0 inet #{node[:lxc][:knife][:bridge_address]}",
      '  bridge_ports eth1',
      '  bridge_stp off',
      '  bridge_maxwait 0',
      '  bridge_fd 0'
    ].each{|line| contents << line}
    f_r = Chef::Resource::File.new('/etc/network/interfaces')
    f_r.content contents.join("\n")
    f_r.run_action(:create)
  end
  not_if do
    File.read('/etc/network/interfaces').include?('auto br0')
  end
  notifies :run, 'execute[restart networking]', :immediately
end

unless(node[:lxc][:bridge] == 'br0')
  node[:lxc][:bridge] = 'br0'
  service 'lxc' do
    action :restart
  end
end

lxc_container 'knife_base' do
  action :create
  chef_enabled false
end
