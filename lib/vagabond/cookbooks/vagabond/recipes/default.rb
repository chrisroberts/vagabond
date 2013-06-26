
# TODO: Move this to lxc cookbook proper at some point
# TODO: Test this on fresh node to ensure start up scripts actuall do
# what they are expected to
=begin
dpkg_autostart 'lxc' do
  allow false
end

dpkg_autostart 'lxc-net' do
  allow false
end

# Start at 0 and increment up if found
unless(node[:network][:interfaces][:lxcbr0])
  max = node.network.interfaces.map do |name, val|
    Array(val[:routes]).map do |route|
      if(route[:family] == 'inet' && route[:destination].start_with?('10.0'))
        route[:destination].split('/').first.split('.')[3].to_i
      end
    end
  end.compact.max

  node.default[:vagabond][:lxc_network][:oct] = max ? max + 1 : 0
  
  # Test for existing bridge. Use different subnet if found
  l_net = "10.0.#{node[:vagabond][:lxc_network][:oct]}"

  node.set[:lxc][:addr] = "#{l_net}.1"
  node.set[:lxc][:network] = "#{l_net}.0/24"
  node.set[:lxc][:dhcp_range] = "#{l_net}.2,#{l_net}.199"
  node.set[:lxc][:dhcp_max] = '199'
end
=end

include_recipe 'lxc'

ruby_block 'LXC template: lxc-centos' do
  block do
    dir = %w(/usr/share /usr/lib).map do |prefix|
      if(File.directory?(d = File.join(prefix, 'lxc/templates')))
        d
      end
    end.compact.first
    raise 'Failed to locate LXC template directory' unless dir
    cfl = Chef::Resource::CookbookFile.new(
      ::File.join(dir, 'lxc-centos'),
      run_context
    )
    cfl.source 'lxc-centos'
    cfl.mode 0755
    cfl.cookbook cookbook_name.to_s
    cfl.action :nothing
    cfl.run_action(:create)
  end
end

node[:vagabond][:bases].each do |name, options|
  
  next unless options[:enabled]

  pkg_coms = [
    'update -y -q',
    'upgrade -y -q',
    'install curl -y -q'
  ]
  if(!options[:template].scan(%r{debian|ubuntu}).empty?)
    pkg_man = 'apt-get'
  elsif(!options[:template].scan(%r{fedora|centos}).empty?)
    pkg_man = 'yum'
  end
  if(pkg_man)
    pkg_coms.map! do |c|
      "#{pkg_man} #{c}"
    end
  else
    pkg_coms = []
  end

  lxc_container name do
    template options[:template]
    template_opts options[:template_options]
    default_config false if options[:memory]
    create_environment options[:environment] if options[:environment]
    initialize_commands [
      'locale-gen en_US.UTF-8',
      'update-locale LANG="en_US.UTF-8"',
      'rm -f /etc/sysctl.d/10-console-messages.conf',
      'rm -f /etc/sysctl.d/10-ptrace.conf',
      'rm -f /etc/sysctl.d/10-kernel-hardening.conf'
    ] + pkg_coms + [
      'curl -L https://www.opscode.com/chef/install.sh | bash'
    ]
  end
end

lxc_container 'chef-server' do
  clone 'ubuntu_1204'
  initialize_commands [
    
  ]
  only_if do
    node[:vagabond][:server_base]
  end
end

node[:vagabond][:customs].each do |name, options|

  lxc_container name do
    action :create
    clone options[:base]
  end
  
  if(options[:memory])
    lxc_config name do
      cgroup(
        'memory.limit_in_bytes' => options[:memory][:ram],
        'memory.memsw.limit_in_bytes' => (
          Vagabond.get_bytes(options[:memory][:ram]) +
          Vagabond.get_bytes(options[:memory][:swap])
        )
      )
    end
  end
end
