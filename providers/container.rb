def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  new_resource.new_container !new_resource._lxc.exists?
end

action :create do

  #### Add custom key for host based interactions
  directory '/opt/hw-lxc-config' do
    action :create
  end

  execute "lxc host_ssh_key" do
    command "ssh-keygen -P '' -f /opt/hw-lxc-config/id_rsa"
    creates "/opt/hw-lxc-config/id_rsa"
  end

  #### Create container
  execute "lxc create[#{new_resource.name}]" do
    command "lxc-create -n #{new_resource.name} -t #{new_resource.template}"
    only_if do
      !new_resource._lxc.exists? && new_resource.updated_by_last_action(true)
    end
  end

  #### Used by internal resources
  lxc_service "lxc config_restart[#{new_resource.name}]" do
    service_name new_resource.name
    action :nothing
    only_if do
      new_resource._lxc.running?
    end
  end

  #### Create container configuration bits
  if(new_resource.default_config)
    lxc_config new_resource.name do
      action :create
      notifies :restart, resources(:lxc_service => "lxc config_restart[#{new_resource.name}]"), :delayed
    end
  end

  if(new_resource.default_fstab)
    lxc_fstab "proc[#{new_resource.name}]" do
      container new_resource.name
      file_system 'proc'
      mount_point 'proc'
      type 'proc'
      options %w(nodev noexec nosuid)
      notifies :restart, resources(:lxc_service => "lxc config_restart[#{new_resource.name}]"), :delayed
    end
    lxc_fstab "sysfs[#{new_resource.name}]" do
      container new_resource.name
      file_system 'sysfs'
      mount_point 'sys'
      type 'sysfs'
      options 'default'
      notifies :restart, resources(:lxc_service => "lxc config_restart[#{new_resource.name}]"), :delayed
    end
  end

  #### Ensure host has ssh access into container
  directory ::File.join(new_resource._lxc.rootfs, 'root', '.ssh') do
    action :create
  end

  file ::File.join(new_resource._lxc.rootfs, 'root', '.ssh', 'authorized_keys') do
    content "# Chef generated key file\n#{File.read('/opt/hw-lxc-config/id_rsa.pub')}\n"
  end


  if(new_resource.chef_enabled || !new_resource.container_commands.empty?)
    if(new_resource.chef_enabled && new_resource.new_container)

      #### Use cached chef package from host if available
      if(%w(debian ubuntu).include?(new_resource.template) && system('ls /opt/chef-full*.deb 2>1 > /dev/null'))
        execute "lxc copy_chef_full[#{new_resource.name}]" do
          action :nothing
          command "cp /opt/chef-full*.deb /var/lib/lxc/#{new_resource.name}/opt"
          subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
        end

        execute "lxc install_chef_full[#{new_resource.name}]" do
          action :nothing
          command "chroot #{new_resource._lxc.rootfs} dpkg -i `ls #{File.join(new_resource._lxc.rootfs, 'opt', 'chef*.deb')}`"
          subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
        end
        @chef_installed = true
      end

      # TODO: Add resources for RPM install

      #### Setup chef related bits within container
      directory "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef" do
        action :nothing
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end

      template "lxc chef-config[#{new_resource.name}]" do
        source 'client.rb.erb'
        cookbook 'lxc'
        path "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/client.rb"
        variables(
          :validation_client => new_resource.validation_client,
          :node_name => new_resource.node_name || "#{node.name}-#{new_resource.name}",
          :server_uri => new_resource.server_uri
        )
        action :nothing
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end

      file "lxc chef-validator[#{new_resource.name}]" do
        path "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/validator.pem"
        content new_resource.validator_pem || node[:lxc][:validator_pem]
        action :nothing
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end

      file "lxc chef-runlist[#{new_resource.name}]" do
        path "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/first_run.json"
        content({:run_list => new_resource.run_list}.to_json)
        action :nothing
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end

      #### Provide data bag secret file if required
      if(new_resource.copy_data_bag_secret_file)
        if ::File.readable?(new_resource.data_bag_secret_file)
          file "lxc chef-data-bag-secret[#{new_resource.name}]" do
            path "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/encrypted_data_bag_secret"
            content ::File.open(new_resource.data_bag_secret_file, "rb").read
            mode 0600
            action :nothing
            subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
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
      action :nothing
      subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
    end

    if(new_resource.chef_enabled && new_resource.new_container)
      # Make sure we have chef in the container
      unless(@chef_installed)
        # Use remote file to remove curl dep
        remote_file "lxc chef_install_script[#{new_resource.name}]" do
          source "http://opscode.com/chef/install.sh"
          path File.join(new_resource._lxc.rootfs, 'opt', 'chef-install.sh')
          action :nothing
          subscribes :create_if_missing, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
        end

        ruby_block "lxc install_chef[#{new_resource.name}]" do
          block do
            new_resource._lxc.container_command(
              "bash /opt/chef-install.sh"
            )
          end
          action :nothing
          subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
        end
      end

      #### Let chef configure the container
      ruby_block "lxc run_chef[#{new_resource.name}]" do
        block do
          new_resource._lxc.container_command(
            "chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json", 3
          )
        end
        action :nothing
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
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
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
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
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end
    end

    #### NOTE: Creation always leaves the container in a stopped state
    ruby_block "lxc shutdown[#{new_resource.name}]" do
      block do
        new_resource._lxc.shutdown
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
    end

    #### Clean up after chef if it's enabled
    if(new_resource.chef_enabled)
      file "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/first_run.json" do
        action :nothing
        subscribes :delete, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end
      
      file "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/validation.pem" do
        action :nothing
        subscribes :delete, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
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
        first_run = true
        begin
          Class.new.send(:include, Chef::Mixin::ShellOut).new.shell_out!(
            "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{new_resource._lxc.container_ip(5)} chef-client"
          )
        rescue => e
          if(first_run)
            first_run = false
            sleep(2)
            retry
          else
            raise e
          end
        end
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
