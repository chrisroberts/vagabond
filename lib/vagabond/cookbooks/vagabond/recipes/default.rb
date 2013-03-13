include_recipe 'lxc::install_dependencies'

cookbook_file '/usr/share/lxc/templates/lxc-centos' do
  source 'lxc-centos'
  mode 0755
end

node[:vagabond][:bases].each do |name, options|
  
  next unless options[:enabled]

  pkg_coms = [
    'update -y -q',
    'upgrade -y -q',
    'install curl -y -q'
  ]
  if(%w(debian ubuntu).include?(options[:template]))
    pkg_man = 'apt-get'
  elsif(%w(fedora centos).include?(options[:template]))
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

  if(options[:memory])
    lxc_config name do
      cgroup(
        'memory.limit_in_bytes' => options[:memory][:maximum_ram],
        'memory.memsw.limit_in_bytes' => (
          Vagabond.get_bytes(options[:memory][:maximum_ram]) +
          Vagabond.get_bytes(options[:memory][:maximum_swap])
        )
      )
    end
  end
end


