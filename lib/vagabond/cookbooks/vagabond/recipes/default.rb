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
      'rm -f /etc/sysctl.d/10-console-messages.conf',
      'rm -f /etc/sysctl.d/10-ptrace.conf',
      'rm -f /etc/sysctl.d/10-kernel-hardening.conf'
    ] + pkg_coms + [
      'curl -L https://www.opscode.com/chef/install.sh | bash'
    ]
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

default[:lxc][:container_directory] = '/var/lib/lxc'
execute "chown -R :admin #{node[:lxc][:container_directory]}"
execute "find #{node[:lxc][:container_directory]} -type d -exec chmod 715 {} +"
execute "find #{node[:lxc][:container_directory]} -type f -exec chmod 664 {} +"
