
cookbook_file '/usr/share/lxc/templates/lxc-centos' do
  source 'lxc-centos'
  mode 0755
end

node[:vagabond][:bases].each do |name, options|

  lxc_container name do
    template options[:template]
    template_opts options[:template_options]
    default_config false if options[:memory]
    initialize_commands [
      'rm -f /etc/sysctl.d/10-console-messages.conf',
      'rm -f /etc/sysctl.d/10-ptrace.conf',
      'rm -f /etc/sysctl.d/10-kernel-hardening.conf',
      'apt-get install -q -y curl',
      'curl -L https://www.opscode.com/chef/install.sh | sudo bash'
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


