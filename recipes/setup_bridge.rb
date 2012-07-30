package 'bridge-utils'

# Lets build a bridge!

# flush here?
execute "lxc[kill the network]" do
  command "ifconfig #{node[:lxc][:bridge][:interface]} 0.0.0.0"
  not_if do
    system("ip addr show #{node[:lxc][:bridge][:name]} > /dev/null 2>&1")
  end
end

execute "lxc[create the bridge]" do
  command "brctl addbr #{node[:lxc][:bridge][:name]}"
  action :nothing
  subscribes :run, resources(:execute => 'lxc[kill the network]'), :immediately
end

execute 'lxc[bind the bridge]' do
  command "brctl addif #{node[:lxc][:bridge][:name]} #{node[:lxc][:bridge][:interface]}"
  action :nothing
  subscribes :run, resources(:execute => 'lxc[kill the network]'), :immediately
end

if(node[:lxc][:bridge][:dhcp])
  execute 'lxc[configure the bridge (dynamic)]' do
    command "dhclient #{node[:lxc][:bridge][:name]}"
    action :nothing
    subscribes :run, resources(:execute => 'lxc[kill the network]'), :immediately
  end
else
  execute 'lxc[configure the bridge (static)]' do
    command "ifconfig #{node[:lxc][:bridge][:name]} #{node[:lxc][:bridge][:address]} netmask #{node[:lxc][:bridge][:netmask]}"
    action :nothing
    subscribes :run, resources(:execute => 'lxc[kill the network]'), :immediately
  end
end

# YAY we built a bridge!
