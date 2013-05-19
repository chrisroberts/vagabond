def load_current_resource
  @lxc = ::Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  new_resource.subresources.map! do |s_r|
    s_r.first.run_context = run_context
    s_r.first.instance_eval(&s_r.last)
    s_r.first
  end
  
  # TODO: Use some actual logic here, sheesh
  if(new_resource.static_ip && new_resource.static_gateway.nil?)
    raise "Static gateway must be defined when static IP is provided (Container: #{new_resource.name})"
  end
  new_resource.default_bridge node[:lxc][:bridge] unless new_resource.default_bridge
  node.run_state[:lxc] ||= Mash.new
  node.run_state[:lxc][:meta] ||= Mash.new
  node.run_state[:lxc][:meta][new_resource.name] = Mash.new(
    :new_container => !@lxc.exists?,
    :lxc => @lxc
  )
end

action :create do
  _lxc = @lxc # for use inside resources
  stopped_end_state = _lxc.stopped?

  #### Add custom key for host based interactions
  directory '/opt/hw-lxc-config' do
    recursive true
  end

  execute 'lxc host_ssh_key' do
    command "ssh-keygen -P '' -f /opt/hw-lxc-config/id_rsa"
    creates '/opt/hw-lxc-config/id_rsa'
  end

  #### Create container
  lxc new_resource.name do
    if(new_resource.clone)
      action :clone
      base_container new_resource.clone
    else
      action :create
      template new_resource.template
      template_opts new_resource.template_opts
    end
  end

  #### Create container configuration bits
  if(new_resource.default_config)
    lxc_config new_resource.name do
      action :create
      default_bridge new_resource.default_bridge
    end
  end

  if(new_resource.default_fstab)
    lxc_fstab "proc[#{new_resource.name}]" do
      container new_resource.name
      file_system 'proc'
      mount_point 'proc'
      type 'proc'
      options %w(nodev noexec nosuid)
    end

    lxc_fstab "sysfs[#{new_resource.name}]" do
      container new_resource.name
      file_system 'sysfs'
      mount_point 'sys'
      type 'sysfs'
      options 'default'
    end
  end

  if(new_resource.static_ip)
    lxc_interface "eth0[#{new_resource.name}]" do
      container new_resource.name
      device 'eth0'
      address new_resource.static_ip
      netmask new_resource.static_netmask
      gateway new_resource.static_gateway
    end
  end

  ruby_block "LXC #{new_resource.name} - Run subresources" do
    block do
      new_resource.subresources.each do |s_r|
        s_r.run_action(:create)
      end
    end
    not_if do
      new_resource.subresources.empty?
    end
  end

  template @lxc.path.join('fstab').to_path do
    source 'fstab.erb'
    cookbook 'lxc'
    variables :container => new_resource.name
    only_if do
      node.run_state[:lxc][:fstabs] &&
        node.run_state[:lxc][:fstabs][new_resource.name]
    end
    mode 0644
  end

  template @lxc.rootfs.join('etc/network/interfaces').to_path do
    source 'interface.erb'
    cookbook 'lxc'
    variables :container => new_resource.name
    mode 0644
    only_if do
      node.run_state[:lxc][:interfaces] &&
        node.run_state[:lxc][:interfaces][new_resource.name]
    end
  end

  #### Ensure host has ssh access into container
  directory @lxc.rootfs.join('root/.ssh').to_path

  template @lxc.rootfs.join('root/.ssh/authorized_keys').to_path do
    source 'file_content.erb'
    cookbook 'lxc'
    mode 0600
    variables(:path => '/opt/hw-lxc-config/id_rsa.pub')
  end

  #### Use cached chef package from host if available
  if(%w(debian ubuntu).include?(new_resource.template) && system('ls /opt/chef*.deb 2>1 > /dev/null'))
    if(::File.directory?('/opt'))
      file_name = Dir.new('/opt').detect do |item| 
        item.start_with?('chef') && item.end_with?('.deb')
      end
    end
    
    execute "lxc copy_chef_full[#{new_resource.name}]" do
      command "cp /opt/#{file_name} #{_lxc.rootfs.join('opt')}"
      not_if do
        file_name.nil? || !new_resource.chef_enabled || _lxc.rootfs.join('opt', file_name).exist?
      end
    end
        
    execute "lxc install_chef_full[#{new_resource.name}]" do
      action :nothing
      command "chroot #{_lxc.rootfs} dpkg -i #{::File.join('/opt', file_name)}"
      subscribes :run, "execute[lxc copy_chef_full[#{new_resource.name}]]", :immediately
    end
  elsif(new_resource.chef_enabled)
    pkg_coms = ['update -y -q', 'upgrade -y -q','install curl -y -q']
    if(!new_resource.template.to_s.scan(%r{debian|ubuntu}).empty?)
      pkg_man = 'apt-get'
    elsif(!new_resource.template.to_s.scan(%r{fedora|centos}).empty?)
      pkg_man = 'yum'
    end
    if(pkg_man)
      new_resource.initialize_commands(
        pkg_coms.map do |c|
          "#{pkg_man} #{c}"
        end + new_resource.initialize_commands
      )
    end
  end

  ruby_block "lxc lock_default_users" do
    block do
      contents = ::File.readlines(_lxc.rootfs.join('etc/shadow').to_path)
      ::File.open(_lxc.rootfs.join('etc/shadow').to_path, 'w') do |file|
        contents.each do |line|
          parts = line.split(':')
          if(node[:lxc][:user_locks].include?(parts.first) && !parts[1].start_with?('!'))
            parts[1] = "!#{parts[1]}"
          end
          file.write parts.join(':')
        end
      end
    end
    only_if do
      ::File.readlines(_lxc.rootfs.join('etc/shadow').to_path).detect do |line|
        parts = line.split(':')
        node[:lxc][:user_locks].include?(parts.first) && !parts[1].start_with?('!')
      end
    end
  end

  ruby_block "lxc default_password_scrub" do
    block do
      contents = ::File.readlines(_lxc.rootfs.join('etc/shadow').to_path)
      ::File.open(_lxc.rootfs.join('etc/shadow'), 'w') do |file|
        contents.each do |line|
          if(line.start_with?('root:'))
            line.sub!(%r{root:.+?:}, 'root:*')
          end
          file.write line
        end
      end
    end
    not_if "grep 'root:*' #{_lxc.rootfs.join('etc/shadow').to_path}"
  end

  ruby_block "lxc start[#{new_resource.name}]" do
    block do
      _lxc.start
    end
    only_if do
      _lxc.rootfs.join('etc/chef/first_run.json').exist? ||
        !new_resource.container_commands.empty? ||
        (node.run_state[:lxc][:meta][new_resource.name][:new_container] && new_resource.initialize_commands)
    end
  end
    
  #### Have initialize commands for the container? Run them now
  ruby_block "lxc initialize_commands[#{new_resource.name}]" do
    block do
      new_resource.initialize_commands.each do |cmd|
        Chef::Log.info "Running command on #{new_resource.name}: #{cmd}"
        _lxc.container_command(cmd, 2)
      end
    end
    only_if do
      node.run_state[:lxc][:meta][new_resource.name][:new_container] &&
        !new_resource.initialize_commands.empty?
    end
  end

  # Make sure we have chef in the container
  remote_file "lxc chef_install_script[#{new_resource.name}]" do
    source "http://opscode.com/chef/install.sh"
    path _lxc.rootfs.join('opt/chef-install.sh').to_path
    action :create_if_missing
    only_if do
      new_resource.chef_enabled && !_lxc.rootfs.join('usr/bin/chef-client').exist?
    end
  end

  ruby_block "lxc install_chef[#{new_resource.name}]" do
    block do
      _lxc.container_command('bash /opt/chef-install.sh')
    end
    action :create
    only_if do
      new_resource.chef_enabled &&
        !_lxc.rootfs.join('usr/bin/chef-client').exist? &&
        _lxc.rootfs.join('opt/chef-install.sh').exist?
    end
  end

  #### Setup chef related bits within container
  directory @lxc.rootfs.join('etc/chef').to_path do
    action :create
    mode 0755
    only_if{ new_resource.chef_enabled }
  end

  template "lxc chef-config[#{new_resource.name}]" do
    source 'client.rb.erb'
    cookbook 'lxc'
    path _lxc.rootfs.join('etc/chef/client.rb').to_path
    variables(
      :validation_client => new_resource.validation_client || Chef::Config[:validation_client_name],
      :node_name => new_resource.node_name || "#{node.name}-#{new_resource.name}",
      :server_uri => new_resource.server_uri || Chef::Config[:chef_server_url],
      :chef_environment => new_resource.chef_environment || '_default'
    )
    mode 0644
    only_if{ new_resource.chef_enabled }
  end

  file "lxc chef-validator[#{new_resource.name}]" do
    path _lxc.rootfs.join('etc/chef/validator.pem').to_path
    content new_resource.validator_pem || node[:lxc][:validator_pem]
    mode 0600
    only_if{ new_resource.chef_enabled && !_lxc.rootfs.join('etc/chef/client.pem').exist? }
  end

  file "lxc chef-runlist[#{new_resource.name}]" do
    path _lxc.rootfs.join('etc/chef/first_run.json').to_path
    content({:run_list => new_resource.run_list}.to_json)
    only_if do
      new_resource.chef_enabled && !_lxc.rootfs.join('etc/chef/client.pem').exist?
    end
    mode 0644
  end

  file "lxc chef-data-bag-secret[#{new_resource.name}]" do
    path _lxc.rootfs.join('etc/chef/encrypted_data_bag_secret').to_path
    content(
      ::File.exists?(new_resource.data_bag_secret_file) ? ::File.open(new_resource.data_bag_secret_file, "rb").read : ''
    )
    mode 0600
    only_if do
      new_resource.chef_enabled &&
      new_resource.copy_data_bag_secret_file &&
        ::File.exists?(new_resource.copy_data_bag_secret_file)
    end
  end
  
  #### Let chef configure the container
  # NOTE: We run chef-client if the validator.pem exists and the
  # client.pem file does not exist.
  ruby_block "lxc run_chef[#{new_resource.name}]" do
    block do
      cmd = 'chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json'
      Chef::Log.info "Running command on #{new_resource.name}: #{cmd}"      
      _lxc.container_command(cmd, new_resource.chef_retries)
    end
    only_if do
      new_resource.chef_enabled &&
        _lxc.rootfs.join('etc/chef/validator.pem').exist? &&
        !_lxc.rootfs.join('etc/chef/client.pem').exist?
    end
  end

  #### Have commands for the container? Run them now
  ruby_block "lxc container_commands[#{new_resource.name}]" do
    block do
      new_resource.container_commands.each do |cmd|
        _lxc.container_command(cmd, 2)
      end
    end
    not_if do
      new_resource.container_commands.empty?
    end
  end

  # NOTE: If the container was not running before we started, make
  # sure we leave it in a stopped state
  ruby_block "lxc shutdown[#{new_resource.name}]" do
    block do
      _lxc.shutdown
    end
    only_if do
      stopped_end_state && _lxc.running?
    end
  end
  
  #### Clean up after chef if it's enabled
  file @lxc.rootfs.join('etc/chef/first_run.json').to_path do
    action :delete
  end

  file @lxc.rootfs.join('etc/chef/validator.pem').to_path do
    action :delete
  end
    
end

action :delete do
  lxc new_resource.name do
    action :delete
  end
end
