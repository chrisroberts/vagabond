def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  # TODO: Use some actual logic here, sheesh
  if(new_resource.static_ip && new_resource.static_gateway.nil?)
    new_resource.static_gateway new_resource.static_ip.sub(/\d+$/, '1')
  end
  new_resource.default_bridge node[:lxc][:bridge] unless new_resource.default_bridge
  new_resource.new_container !new_resource._lxc.exists?
end

action :create do

  #### Add custom key for host based interactions
  lxc_dir = directory '/opt/hw-lxc-config' do
    action :nothing
  end
  lxc_dir.run_action(:create)

  lxc_key = execute "lxc host_ssh_key" do
    command "ssh-keygen -P '' -f /opt/hw-lxc-config/id_rsa"
    creates "/opt/hw-lxc-config/id_rsa"
    action :nothing
  end
  lxc_key.run_action(:run)

  #### Create container
  execute "lxc create[#{new_resource.name}]" do
    command "lxc-create -n #{new_resource.name} -t #{new_resource.template}"
    only_if do
      !new_resource._lxc.exists? && new_resource.updated_by_last_action(true)
    end
  end

  #### Create container configuration bits
  if(new_resource.default_config)
    lxc_config new_resource.name do
      action :create
      default_bridge new_resource.default_bridge
      static_ip new_resource.static_ip
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

    ruby_block "force container gateway[#{new_resource.name}]" do
      block do
        file = Chef::Util::FileEdit.new(
          ::File.join(
            new_resource._lxc.rootfs, 'etc', 'rc.local'
          )
        )
        file.search_file_delete_line(%r{route add default gw})
        file.search_file_replace(
          %r{exit 0$},
          "route add default gw #{new_resource.static_gateway}\nexit 0"
        )
        file.write_file
      end
      not_if "grep \"route add default gw #{new_resource.static_gateway}\" #{::File.join(new_resource._lxc.rootfs, 'etc', 'rc.local')}"
    end
  end

  #### Ensure host has ssh access into container
  directory ::File.join(new_resource._lxc.rootfs, 'root', '.ssh')

  file ::File.join(new_resource._lxc.rootfs, 'root', '.ssh', 'authorized_keys') do
    content "# Chef generated key file\n#{::File.read('/opt/hw-lxc-config/id_rsa.pub')}\n"
  end

  if(new_resource.chef_enabled || !new_resource.container_commands.empty?)
    if(new_resource.chef_enabled && new_resource.new_container)

      #### Use cached chef package from host if available
      if(%w(debian ubuntu).include?(new_resource.template) && system('ls /opt/chef*.deb 2>1 > /dev/null'))
        file_name = Dir.new('/opt').detect do |item| 
          item.start_with?('chef') && item.end_with?('.deb')
        end
        if(file_name)
          execute "lxc copy_chef_full[#{new_resource.name}]" do
            command "cp /opt/#{file_name} #{::File.join(new_resource._lxc.rootfs, 'opt')}"
            not_if do
              ::File.exists?(
                ::File.join(new_resource._lxc.rootfs, 'opt', file_name)
              )
            end
          end

          execute "lxc install_chef_full[#{new_resource.name}]" do
            action :nothing
            command "chroot #{new_resource._lxc.rootfs} dpkg -i #{::File.join('/opt', file_name)}"
            subscribes :run, resources(:execute => "lxc copy_chef_full[#{new_resource.name}]"), :immediately
          end
          @chef_installed = true
        end
      end

      # TODO: Add resources for RPM install

      #### Setup chef related bits within container
      directory ::File.join(new_resource._lxc.rootfs, 'etc', 'chef') do
        action :create
        mode 0755
      end

      template "lxc chef-config[#{new_resource.name}]" do
        source 'client.rb.erb'
        cookbook 'lxc'
        path ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'client.rb')
        variables(
          :validation_client => new_resource.validation_client,
          :node_name => new_resource.node_name || "#{node.name}-#{new_resource.name}",
          :server_uri => new_resource.server_uri
        )
        mode 0644
      end

      file "lxc chef-validator[#{new_resource.name}]" do
        path ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'validator.pem')
        content new_resource.validator_pem || node[:lxc][:validator_pem]
        mode 0600
      end

      file "lxc chef-runlist[#{new_resource.name}]" do
        path ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'first_run.json')
        content({:run_list => new_resource.run_list}.to_json)
        not_if do
          ::File.exists?(
            ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'client.pem')
          )
        end
        mode 0644
      end

      #### Provide data bag secret file if required
      if(new_resource.copy_data_bag_secret_file)
        if ::File.readable?(new_resource.data_bag_secret_file)
          file "lxc chef-data-bag-secret[#{new_resource.name}]" do
            path ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'encrypted_data_bag_secret')
            content ::File.open(new_resource.data_bag_secret_file, "rb").read
            mode 0600
            action :nothing
          end
        else
          Chef::Log.warn "Could not read #{new_resource.data_bag_secret_file}"
        end
      end
    end

    ruby_block "lxc start[#{new_resource.name}]" do
      block do
        new_resource._lxc.start
      end
      only_if do
        ::File.exists?(
          ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'first_run.json')
        )
      end
    end

    if(new_resource.chef_enabled && new_resource.new_container)
      # Make sure we have chef in the container
      unless(@chef_installed)
        # Use remote file to remove curl dep
        remote_file "lxc chef_install_script[#{new_resource.name}]" do
          source "http://opscode.com/chef/install.sh"
          path ::File.join(new_resource._lxc.rootfs, 'opt', 'chef-install.sh')
          action :create_if_missing
        end

        ruby_block "lxc install_chef[#{new_resource.name}]" do
          block do
            new_resource._lxc.container_command(
              "bash /opt/chef-install.sh"
            )
          end
          not_if do
            File.exists?(new_resource._lxc.rootfs, 'usr', 'bin', 'chef-client')
          end
        end
      end

      #### Let chef configure the container
      ruby_block "lxc run_chef[#{new_resource.name}]" do
        block do
          new_resource._lxc.container_command(
            "chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json",
            new_resource.chef_retries
          )
        end
        not_if do
          ::File.exists?(
            ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'client.pem')
          )
        end
      end
    end

    #### Have initialize commands for the container? Run them now
    if(new_resource.new_container && !new_resource.initialize_commands.empty?)
      ruby_block "lxc initialize_commands[#{new_resource.name}]" do
        block do
          new_resource.container_commands.each do |cmd|
            new_resource._lxc.container_command(cmd, 2)
          end
        end
      end
    end

    #### Have commands for the container? Run them now
    unless(new_resource.container_commands.empty?)
      ruby_block "lxc container_commands[#{new_resource.name}]" do
        block do
          new_resource.container_commands.each do |cmd|
            new_resource._lxc.container_command(cmd, 2)
          end
        end
      end
    end

    #### NOTE: Creation always leaves the container in a stopped state
    ruby_block "lxc shutdown[#{new_resource.name}]" do
      block do
        new_resource._lxc.shutdown
      end
      only_if do
        new_resource.new_container
      end
    end

    #### Clean up after chef if it's enabled
    if(new_resource.chef_enabled)
      file ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'first_run.json') do
        action :delete
      end
      
      file ::File.join(new_resource._lxc.rootfs, 'etc', 'chef', 'validator.pem') do
        action :delete
      end
    end
  end

end

action :delete do
  ruby_block "lxc stop[#{new_resource.name}]" do
    block do
      new_resource._lxc.stop
    end
    only_if do
      new_resource._lxc.running?
    end
  end
  
  execute "lxc delete[#{new_resource.name}]" do
    command "lxc-destroy -n #{new_resource.name}"
    only_if do
      new_resource._lxc.exists? && new_resource.updated_by_last_action(true)
    end
  end
end

action :clone do
  execute "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]" do
    command "lxc-clone -o #{new_resource.base_container} -n #{new_resource.name}"
    only_if do
      !new_resource._lxc.exists? && new_resource.updated_by_last_action(true)
    end
  end

  lxc_service "lxc config_restart[#{new_resource.name}]" do
    service_name new_resource.name
    action :nothing
    only_if do
      new_resource._lxc.running?
    end
  end
  
  lxc_config new_resource.name do
    config new_resource.config
    action :create
    notifies :restart, resources(:lxc_service => "lxc config_restart[#{new_resource.name}]"), :immediately
  end
  
  if(new_resource.chef_enabled)
    ruby_block "lxc start[#{new_resource.name}]" do
      block do
        new_resource._lxc.start
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end

    ruby_block "lxc run_chef[#{new_resource.name}]" do
      block do
        new_resource._lxc.container_command(
          "chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json", 3
        )
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end
 
    ruby_block "lxc shutdown[#{new_resource.name}]" do
      block do
        new_resource._lxc.shutdown
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end
  end
end
