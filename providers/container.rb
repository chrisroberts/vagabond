def load_current_resource
  new_resource.new_container !Lxc.exists?(new_resource.name)
  if(new_resource.chef_enabled && new_resource.template != 'ubuntu-hw')
    raise 'Chef enabled containers currently only supported on ubuntu-hw container'
  end
end

action :create do

  execute "lxc create[#{new_resource.name}]" do
    command "lxc-create -n #{new_resource.name} -t #{new_resource.template} #{"-- --ipaddress #{new_resource.static_ip}" if new_resource.static_ip}"
    only_if do
      !Lxc.exists?(new_resource.name) &&
      new_resource.updated_by_last_action(true)
    end
  end

  lxc_service "lxc config_restart[#{new_resource.name}]" do
    service_name new_resource.name
    action :nothing
    only_if do
      Lxc.running?(new_resource.name)
    end
  end
  
  lxc_config new_resource.name do
    config new_resource.config
    action :create
    notifies :restart, resources(:lxc_service => "lxc config_restart[#{new_resource.name}]"), :delayed
  end

  if(new_resource.chef_enabled || !new_resource.container_commands.empty?)
  
    if(new_resource.chef_enabled && new_resource.new_container)
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

      if new_resource.copy_data_bag_secret_file
        if ::File.readable?(new_resource.data_bag_secret_file)
          file "lxc chef-data-bag-secret[#{new_resource.name}]" do
            path "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/encrypted_data_bag_secret"
            content(::File.open(new_resource.data_bag_secret_file, "rb").read)
            mode 0600
            action :nothing
            subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
          end
        else
          Chef::Log.warn("Could not read #{new_resource.data_bag_secret_file}")
        end
      end
    end

    ruby_block "lxc start[#{new_resource.name}]" do
      block do
        Lxc.start(new_resource.name)
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
    end

    if(new_resource.chef_enabled && new_resource.new_container)
      ruby_block "lxc run_chef[#{new_resource.name}]" do
        block do
          Lxc.container_command(
            new_resource.name,
            "chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json",
            3
          )
        end
        action :nothing
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end
    end

    if(new_resource.new_container && !new_resource.initialize_commands.empty?)
      ruby_block "lxc initialize_commands[#{new_resource.name}]" do
        block do
          new_resource.container_commands.each do |cmd|
            Lxc.container_command(
              new_resource.name,
              cmd,
              2
            )
          end
        end
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end
    end

    unless(new_resource.container_commands.empty?)
      ruby_block "lxc container_commands[#{new_resource.name}]" do
        block do
          new_resource.container_commands.each do |cmd|
            Lxc.container_command(
              new_resource.name,
              cmd,
              2
            )
          end
        end
        subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
      end
    end

    ruby_block "lxc shutdown[#{new_resource.name}]" do
      block do
        Lxc.shutdown(new_resource.name)
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc create[#{new_resource.name}]"), :immediately
    end

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
      Lxc.stop(new_resource.name)
    end
    only_if do
      Lxc.running?(new_resource.name)
    end
  end
  
  execute "lxc delete[#{new_resource.name}]" do
    command "lxc-destroy -n #{new_resource.name}"
    only_if do
      Lxc.exists?(new_resource.name) &&
      new_resource.updated_by_last_action(true)
    end
  end
end

action :clone do
  execute "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]" do
    command "lxc-clone -o #{new_resource.base_container} -n #{new_resource.name}"
    only_if do
      !Lxc.exists?(new_resource.name) &&
      new_resource.updated_by_last_action(true)
    end
  end

  lxc_service "lxc config_restart[#{new_resource.name}]" do
    service_name new_resource.name
    action :nothing
    only_if do
      Lxc.running?(new_resource.name)
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
        Lxc.start(new_resource.name)
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end

    ruby_block "lxc run_chef[#{new_resource.name}]" do
      block do
        first_run = true
        begin
          Class.new.send(:include, Chef::Mixin::ShellOut).new.shell_out!(
            "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{Lxc.container_ip(new_resource.name, 5)} chef-client"
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
        Lxc.shutdown(new_resource.name)
      end
      action :nothing
      subscribes :create, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end
  end
end
