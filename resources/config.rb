actions :create, :delete
default_action :create

attribute :utsname, :kind_of => String, :default => nil # defaults to resource name
attribute :network, :kind_of => [Array, Hash]
attribute :default_bridge, :kind_of => String
attribute :static_ip, :kind_of => String
attribute :pts, :kind_of => Numeric, :default => 1024
attribute :tty, :kind_of => Numeric, :default => 4
attribute :arch, :kind_of => String, :default => 'amd64'
attribute :devttydir, :kind_of => String, :default => 'lxc'
attribute :cgroup, :kind_of => Hash, :default => {
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
}
attribute :cap_drop, :kind_of => [String, Array], :default => %w(sys_module mac_admin)
attribute :mount, :kind_of => String
attribute :mount_entry, :kind_of => String
attribute :rootfs, :kind_of => String
attribute :rootfs_mount, :kind_of => String
attribute :pivotdir, :kind_of => String
attribute :_lxc
