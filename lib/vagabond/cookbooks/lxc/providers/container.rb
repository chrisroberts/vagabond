def load_current_resource
  @lxc = Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  # TODO: Use some actual logic here, sheesh
  if(new_resource.static_ip && new_resource.static_gateway.nil?)
    raise "Static gateway must be defined when static IP is provided (Container: #{new_resource.name})"
  end
  new_resource.default_bridge node[:lxc][:bridge] unless new_resource.default_bridge
  node.run_state[:lxc][:meta] ||= Mash.new
  node.run_state[:lxc][:meta][new_resource.name] = Mash.new(
    :new_container => @lxc.exists?,
    :lxc => @lxc
  )
end

action :create do
  _lxc = @lxc # for use inside resources

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
  
  template @lxc.path.join('fstab') do
    source 'fstab.erb'
    variables :container => new_resource.name
    mode 0644
  end

  template @lxc.rootfs.join('etc/network/interfaces') do
    source 'interfaces.erb'
    variables :container => new_resource.name
    mode 0644
  end

  #### Ensure host has ssh access into container
  directory @lxc.rootfs.join('root/.ssh')

  file @lxc.rootfs.join('root/.ssh/authorized_keys') do
    content "# Chef generated key file\n#{::File.read('/opt/hw-lxc-config/id_rsa.pub')}\n"
  end

  if(new_resource.chef_enabled || !new_resource.container_commands.empty? || !new_resource.initialize_commands.empty?)
    if(new_resource.chef_enabled && node.run_state[:lxc][:meta][new_resource.name][:new_container])

      #### Use cached chef package from host if available
      if(%w(debian ubuntu).include?(new_resource.template) && system('ls /opt/chef*.deb 2>1 > /dev/null'))
        file_name = Dir.new('/opt').detect do |item| 
          item.start_with?('chef') && item.end_with?('.deb')
        end
        if(file_name)
          execute "lxc copy_chef_full[#{new_resource.name}]" do
            command "cp /opt/#{file_name} #{_lxc.rootfs.join('opt')}"
            not_if do
              _lxc.rootfs.join('opt', file_name).exist?
            end
          end

          execute "lxc install_chef_full[#{new_resource.name}]" do
            action :nothing
            command "chroot #{_lxc.rootfs} dpkg -i #{::File.join('/opt', file_name)}"
            subscribes :run, "execute[lxc copy_chef_full[#{new_resource.name}]", :immediately
          end
          @chef_installed = true
        end
      end

      # TODO: Add resources for RPM install

      #### Setup chef related bits within container
      directory @lxc.rootfs.join('etc/chef') do
        action :create
        mode 0755
      end

      template "lxc chef-config[#{new_resource.name}]" do
        source 'client.rb.erb'
        cookbook 'lxc'
        path _lxc.rootfs.join('etc/chef/client.rb')
        variables(
          :validation_client => new_resource.validation_client,
          :node_name => new_resource.node_name || "#{node.name}-#{new_resource.name}",
          :server_uri => new_resource.server_uri,
          :chef_environment => new_resource.chef_environment || '_default'
        )
        mode 0644
      end

      file "lxc chef-validator[#{new_resource.name}]" do
        path _lxc.rootfs.join('etc/chef/validator.pem')
        content new_resource.validator_pem || node[:lxc][:validator_pem]
        mode 0600
      end

      file "lxc chef-runlist[#{new_resource.name}]" do
        path _lxc.rootfs.join('etc/chef/first_run.json')
        content({:run_list => new_resource.run_list}.to_json)
        not_if do
          _lxc.rootfs.join('etc/chef/client.pem').exist?
        end
        mode 0644
      end

      #### Provide data bag secret file if required
      if(new_resource.copy_data_bag_secret_file)
        if ::File.readable?(new_resource.data_bag_secret_file)
          file "lxc chef-data-bag-secret[#{new_resource.name}]" do
            path _lxc.rootfs.join('etc/chef/encrypted_data_bag_secret')
            content ::File.open(new_resource.data_bag_secret_file, "rb").read
            mode 0600
          end
        else
          Chef::Log.warn "Could not read #{new_resource.data_bag_secret_file}"
        end
      end
    end

    ruby_block "lxc start[#{new_resource.name}]" do
      block do
        _lxc.start
      end
      only_if do
        _lxc.rootfs.join('etc/chef/first_run.json') ||
          (node.run_state[:lxc][:meta][new_resource.name][:new_container] && new_resource.initialize_commands)
      end
    end

    if(new_resource.chef_enabled && node.run_state[:lxc][:meta][new_resource.name][:new_container])
      # Make sure we have chef in the container
      unless(@chef_installed)
        # Use remote file to remove curl dep
        remote_file "lxc chef_install_script[#{new_resource.name}]" do
          source "http://opscode.com/chef/install.sh"
          path _lxc.rootfs.join('opt/chef-install.sh')
          action :create_if_missing
        end

        ruby_block "lxc install_chef[#{new_resource.name}]" do
          block do
            _lxc.container_command('bash /opt/chef-install.sh')
          end
          not_if do
            _lxc.rootfs.join('usr/bin/chef-client').exist?
          end
        end
      end

      #### Let chef configure the container
      ruby_block "lxc run_chef[#{new_resource.name}]" do
        block do
          _lxc.container_command(
            'chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json',
            new_resource.chef_retries
          )
        end
        not_if do
          _lxc.rootfs.join('etc/chef/client.pem').exist?
        end
      end
    end

    #### Have initialize commands for the container? Run them now
    ruby_block "lxc initialize_commands[#{new_resource.name}]" do
      block do
        new_resource.initialize_commands.each do |cmd|
          _lxc.container_command(cmd, 2)
        end
      end
      only_if do
        node.run_state[:lxc][:meta][new_resource.name][:new_container] &&
          !new_resource.initialize_commands.empty?
      end
    end

    #### Have commands for the container? Run them now
    ruby_block "lxc container_commands[#{new_resource.name}]" do
      block do
        new_resource.container_commands.each do |cmd|
          new_resource._lxc.container_command(cmd, 2)
        end
      end
      not_if do
        new_resource.container_commands.empty?
      end
    end

    #### NOTE: Creation always leaves the container in a stopped state
    ruby_block "lxc shutdown[#{new_resource.name}]" do
      block do
        new_resource._lxc.shutdown
      end
      only_if do
        node.run_state[:lxc][:meta][new_resource.name][:new_container]
      end
    end

    #### Clean up after chef if it's enabled
    file @lxc.rootfs.join('etc/chef/first_run.json') do
      action :delete
    end

    file @lxc.rootfs.join('etc/chef/validator.pem') do
      action :delete
    end
    
  end

end

action :delete do
  lxc new_resource.name do
    action :delete
  end
end
