include_recipe 'lxc'

# This shuts down the default lxcbr0
node[:lxc][:use_bridge] = false
service 'lxc' do
  action :stop
end

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

cookbook_file '/usr/local/bin/knife_lxc' do
  source 'knife_lxc'
  mode 0755
end

node[:lxc][:allowed_types].each do |type|
  lxc_container "#{type}_base" do
    template type
    chef_enabled false
    action :create
  end
end
