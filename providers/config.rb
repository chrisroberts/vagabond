require 'securerandom'

def load_current_resource
  @lxc = ::Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  new_resource.utsname new_resource.name unless new_resource.utsname
  new_resource.rootfs @lxc.rootfs.to_path unless new_resource.rootfs
  new_resource.default_bridge node[:lxc][:bridge] unless new_resource.default_bridge
  new_resource.mount @lxc.path.join('fstab').to_path unless new_resource.mount
  config = LxcFileConfig.new(@lxc.container_config)
  if((new_resource.network.nil? || new_resource.network.empty?))
    if(config.network.empty?)
      default_net = {
        :type => :veth,
        :link => new_resource.default_bridge,
        :flags => :up,
        :hwaddr => "00:16:3e#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}"
      }
    else
      default_net = config.network.first
      default_net.delete(:ipv4) if default_net.has_key?(:ipv4)
      default_net.merge!(:link => new_resource.default_bridge)
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
  _lxc = @lxc
  
  directory @lxc.path.to_path do
    action :create
  end

  file "lxc update_config[#{new_resource.utsname}]" do
    path _lxc.container_config.to_path
    content LxcFileConfig.generate_config(new_resource)
    mode 0644
  end
end
