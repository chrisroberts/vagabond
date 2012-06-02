def load_current_resource
end

action :create do

  execute "lxc create[#{new_resource.name}]" do
    if(node[:lxc][:start_ipaddress])
      base = node[:lxc][:last_ipaddress] || node[:lxc][:start_ipaddress]
      node[:lxc][:last_ipaddress] = Lxc.next_ip(base)
      node[:lxc][new_resource.name] = node[:lxc][:last_ipaddress]
      next_ip = "-- --ipaddress #{node[:lxc][:last_ipaddress]}"
    end
    command "lxc-create -n #{new_resource.name} -t ubuntu-hw #{next_ip}"
    not_if do
      Lxc.exists?(new_resource.name)
    end
  end

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
  
  execute "lxc start[#{new_resource.name}]" do
    command "lxc-start -n #{new_resource.name} -d"
    action :nothing
    subscribes :run, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
  end

  execute "lxc run_chef[#{new_resource.name}]" do
    command "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{node[:lxc][new_resource.name]} chef-client -K /etc/chef/validator.pem -c /etc/chef/client.rb -j /etc/chef/first_run.json"
    action :nothing
    subscribes :run, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
  end

  execute "lxc shutdown[#{new_resource.name}]" do
    command "lxc-shutdown -n #{new_resource.name}"
    action :nothing
    subscribes :run, resources(:template => "lxc chef-config[#{new_resource.name}]"), :immediately
  end

  file "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/first_run.json" do
    action :nothing
    subscribes :delete, resources(:execute => "lxc shutdown[#{new_resource.name}]"), :immediately
  end
  
  file "/var/lib/lxc/#{new_resource.name}/rootfs/etc/chef/validation.pem" do
    action :nothing
    subscribes :delete, resources(:execute => "lxc shutdown[#{new_resource.name}]"), :immediately
  end

  new_resource.updated_by_last_action(true)
end

action :delete do
  execute "lxc shutdown[#{new_resource.name}]" do
    command "lxc-shutdown -n #{new_resource.name}"
    only_if{ Lxc.running?(new_resource.name) }
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

  execute "lxc set_address[#{new_resource.name}]" do
    if(node[:lxc][:start_ipaddress])
      base = node[:lxc][:last_ipaddress] || node[:lxc][:start_ipaddress]
      node[:lxc][:last_ipaddress] = Lxc.next_ip(base)
      node[:lxc][new_resource.name] = node[:lxc][:last_ipaddress]
    end
    command "sed -i 's/lxc\.network\.ipv4.*/lxc.network.ipv4 = #{node[:lxc][:last_ipaddress]}/' /var/lib/lxc/#{new_resource.name}/config"
    action :nothing
    only_if{ node[:lxc][:start_ipaddress] }
    subscribes :run, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
  end

  execute "lxc start[#{new_resource.name}]" do
    command "lxc-start -n #{new_resource.name} -d"
    action :nothing
    subscribes :run, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
  end

  execute "lxc run_chef[#{new_resource.name}]" do
    command "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{node[:lxc][new_resource.name]} chef-client"
    action :nothing
    subscribes :run, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
  end
 
  execute "lxc shutdown[#{new_resource.name}]" do
    command "lxc-shutdown -n #{new_resource.name}"
    action :nothing
    subscribes :run, resources(:execute => "lxc clone[#{new_resource.base_container} -> #{new_resource.name}]"), :immediately
  end

  new_resource.updated_by_last_action(true)
end
