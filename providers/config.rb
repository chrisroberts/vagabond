require 'securerandom'

def load_current_resource
  base_config = {
    'lxc.network.type' => 'veth',
    'lxc.network.link' => 'lxcbr0',
    'lxc.network.flags' => 'up',
    'lxc.network.hwaddr' => "00:16:3e:#{SecureRandom.hex(3).gsub(/(..)/, ':\1')}",
    'lxc.utsname' => new_resource.name,
    'lxc.devttydir' => 'lxc',
    'lxc.tty' => 4,
    'lxc.pts' => 1024,
    'lxc.rootfs' => '/var/lib/lxc/chef_test/rootfs',
    'lxc.mount'  => '/var/lib/lxc/chef_test/fstab',
    'lxc.arch' => 'amd64',
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
  ruby_block "lxc update_config[#{new_resource.name}]" do
    block do
      File.open(Lxc.container_config(new_resource.name), 'w') do |file|
        file.write(
          Lxc.generate_config(
            new_resource.name, 
            new_resource.config
          ).join("\n")
        )
      end
    end
    not_if do
      Lxc.generate_config(
        new_resource.name, 
        new_resource.config
      ) == File.readlines(
        Lxc.container_config(new_resource.name)
      ).sort
    end
  end
end
