def load_current_resource
end

action :create do

  execute "lxc create[#{new_resource.name}]" do
    command "lxc-create -n #{new_resource.name} -t ubuntu-hw #{"-- --ipaddress #{new_resource.static_ip}" if new_resource.static_ip}"
    not_if do
      Lxc.exists?(new_resource.name)
    end
  end

  if(new_resource.chef_enabled)
    
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
      subscribes :create, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end

    file "lxc chef-runlist[#{new_resource.name}]" do
      path "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/first_run.json"
      content({:run_list => new_resource.run_list}.to_json)
      action :nothing
      subscribes :create, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end

    ruby_block "lxc start[#{new_resource.name}]" do
      block do
        Lxc.start(new_resource.name)
      end
      action :nothing
      subscribes :create, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end

    ruby_block "lxc run_chef[#{new_resource.name}]" do
      block do
        Class.new.send(:include, Chef::Mixin::ShellOut).new.shell_out!(
          "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{Lxc.container_ip(new_resource.name, 5)} chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json"
        )
      end
      action :nothing
      subscribes :create, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end

    ruby_block "lxc shutdown[#{new_resource.name}]" do
      block do
        Lxc.shutdown(new_resource.name)
      end
      action :nothing
      subscribes :create, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end

    file "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/first_run.json" do
      action :nothing
      subscribes :delete, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end
    
    file "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/validation.pem" do
      action :nothing
      subscribes :delete, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
    end
  end

  new_resource.updated_by_last_action(true)
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
      Lxc.exists?(new_resource.name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :clone do
  execute "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]" do
    command "lxc-clone -o #{new_resource.base_container} -n #{new_resource.name}"
    not_if do
      Lxc.exists?(new_resource.name)
    end
  end

  if(new_resource.static_ip)
    execute "lxc set_address_sub[#{new_resource.name}]" do
      command "sed -i 's/lxc\.network\.ipv4.*/lxc.network.ipv4 = #{new_resource.static_ip}/' /var/lib/lxc/#{new_resource.name}/config"
      action :nothing
      only_if do
        File.read(File.join(Lxc.container_path(new_resource.name), 'config')).include?('lxc.network.ipv4')
      end
      subscribes :run, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end

    execute "lxc set_address_direct[#{new_resource.name}]" do
      command "echo 'lxc.network.ipv4 = #{new_resource.static_ip}' >> #{File.join(Lxc.container_path(new_resource.name), 'config')}"
      action :nothing
      not_if do
        File.read(File.join(Lxc.container_path(new_resource.name), 'config')).include?('lxc.network.ipv4')
      end
      subscribes :run, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
    end
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

  new_resource.updated_by_last_action(true)
end
