require 'securerandom'

def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  new_resource.utsname new_resource.name unless new_resource.utsname
  new_resource.rootfs new_resource._lxc.rootfs unless new_resource.rootfs
  new_resource.default_bridge node[:lxc][:bridge] unless new_resource.default_bridge
  new_resource.mount ::File.join(new_resource._lxc.path, 'fstab') unless new_resource.mount
  config = LxcFileConfig.new(new_resource._lxc.container_config)
  if((new_resource.network.nil? || new_resource.network.empty?))
    if(config.network.empty?)
      default_net = {
        :type => :veth,
        :link => new_resource.default_bridge,
        :flags => :up,
        :hwaddr => "00:16:3e#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}"
      }
      default_net.merge!(:ipv4 => new_resource.static_ip) if new_resource.static_ip
    else
      default_net = config.network.first
      default_net.merge!(:link => new_resource.default_bridge)
      default_net.merge!(:ipv4 => new_resource.static_ip) if new_resource.static_ip
    end
    new_resource.network(default_net)
  else
    [new_resource.network].flatten.each_with_index do |net_hash, idx|
      if(config.network[idx].nil? || config.network[idx][:hwaddr].nil?)
        net_hash[:hwaddr] ||= "00:16:3e#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}"
      end
    end
  end
  new_resource.cgroup(
    Chef::Mixin::DeepMerge.merge(
      Mash.new(
        'devices.deny' => 'a',
        'devices.allow' => [
          'c *:* m',
          'b *:* m',
          'c 1:3 rwm',
          'c 1:5 rwm',
          'c 5:1 rwm',
          'c 5:0 rwm',
          'c 1:9 rwm',
          'c 1:8 rwm',
          'c 136:* rwm',
          'c 5:2 rwm',
          'c 254:0 rwm',
          'c 10:229 rwm',
          'c 10:200 rwm',
          'c 1:7 rwm',
          'c 10:228 rwm',
          'c 10:232 rwm'
        ]
      ),
      new_resource.cgroup
    )
  )
end

action :create do
  ruby_block "lxc config_updater[#{new_resource.utsname}]" do
    block do
      new_resource.updated_by_last_action(true)
    end
    action :nothing
  end

  directory new_resource._lxc.container_path do
    action :create
  end

  file "lxc update_config[#{new_resource.utsname}]" do
    path new_resource._lxc.container_config
    content LxcFileConfig.generate_config(new_resource)
    mode 0644
    notifies :create, resources(:ruby_block => "lxc config_updater[#{new_resource.utsname}]"), :immediately
  end
end
