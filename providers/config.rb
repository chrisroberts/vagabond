require 'securerandom'

def load_current_resource
  if(::File.exists?(Lxc.container_config(new_resource.name)))
    mac_addr = ::File.readlines(Lxc.container_config(new_resource.name)).detect{|line|
      line.include?('hwaddr')
    }.to_s.split('=').last.to_s.strip
  end
  if(mac_addr.to_s.empty?)
    mac_addr = "00:16:3e#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}" 
  end
  base_config = {
    'lxc.network.type' => 'veth',
    'lxc.network.link' => 'lxcbr0',
    'lxc.network.flags' => 'up',
    'lxc.network.hwaddr' => mac_addr,
    'lxc.utsname' => new_resource.name,
    'lxc.devttydir' => 'lxc',
    'lxc.tty' => 4,
    'lxc.pts' => 1024,
    'lxc.arch' => 'amd64',
    'lxc.rootfs' => "/var/lib/lxc/#{new_resource.name}/rootfs",
    'lxc.mount'  => "/var/lib/lxc/#{new_resource.name}/fstab",
    'lxc.cap.drop' => 'sys_module mac_admin',
    'lxc.cgroup.devices.deny' => 'a',
    'lxc.cgroup.devices.allow' => [
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
  }
  new_resource.config Chef::Mixin::DeepMerge.merge(base_config, new_resource.config)
end

action :create do
  file "lxc update_config[#{new_resource.name}]" do
    path Lxc.container_config(new_resource.name)
    content Lxc.generate_config(new_resource.name, new_resource.config)
    mode 0644
  end
  new_resource.updated_by_last_action(true)
end
