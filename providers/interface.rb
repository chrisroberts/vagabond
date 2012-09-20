def load_current_resource
  @lxc = Lxc.new(
    new_resource.container,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  @loaded ||= {}
  # value checks
  unless(new_resource.dynamic)
    %w(address gateway netmask).each do |key|
      raise "#{key} is required for static interfaces" if new_resource.send(key).nil?
    end
  end
  # address checks
  unless(new_resource.dynamic)
    %w(address gateway).each do |key|
      new_resource.send(key).split('.').each do |oct|
        raise "#{key} is not a valid address" if oct.to_i > 254
      end
    end
    new_resource.netmask.split('.').each do |oct|
      raise 'netmask is not valid' if oct.to_i > 255
    end
  end
  node[:lxc][:interfaces] ||= Mash.new
  node[:lxc][:interfaces][new_resource.container] ||= []
end

action :create do
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
    ruby_block "lxc_interface_notifier[#{new_resource.container}]" do
      action :create
      block{ true }
      only_if do
        new_resource.updated_by_last_action?
      end
    end
    template ::File.join(@lxc.rootfs, 'etc', 'interfaces') do
      source 'interface.erb'
      cookbook 'lxc'
      variables :container => new_resource.container
      subscribes :create, resources(:ruby_block => "lxc_interface_notifier[#{new_resource.container}]"), :delayed
    end
  end

  net_set = Mash.new(:device => new_resource.device)
  if(new_resource.dynamic)
    net_set[:dynamic] = true
  else
    net_set[:address] = new_resource.address
    net_set[:gateway] = new_resource.gateway
    net_set[:netmask] = new_resource.netmask
  end

  unless(node[:lxc][:interfaces][new_resource.container].include?(net_set))
    node[:lxc][:interfaces][new_resource.container] << net_set
    new_resource.updated_by_last_action(true)
  end
end

action :delete do
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
    ruby_block "lxc_interface_notifier[#{new_resource.container}]" do
      action :create
      block{ true }
      only_if do
        new_resource.updated_by_last_action?
      end
    end
    template ::File.join(@lxc.rootfs, 'etc', 'interfaces') do
      cookbook 'lxc'
      source 'interface.erb'
      variables :container => new_resource.container
      subscribes :create, resources(:ruby_block => "lxc_interface_notifier[#{new_resource.container}]"), :delayed
    end
  end

  net_set = Mash.new(:device => new_resource.device)
  if(new_resource.dynamic)
    net_set[:dynamic] = true
  else
    net_set[:address] = new_resource.address
    net_set[:gateway] = new_resource.gateway
    net_set[:netmask] = new_resource.netmask
  end

  if(node[:lxc][:interfaces][new_resource.container].include?(net_set))
    node[:lxc][:interfaces][new_resource.container].delete(net_set)
    new_resource.updated_by_last_action(true)
  end
end
