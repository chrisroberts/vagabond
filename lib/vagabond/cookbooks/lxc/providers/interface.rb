def load_current_resource
  @lxc = ::Lxc.new(
    new_resource.container,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  @loaded ||= {}
  # value checks
  unless(new_resource.dynamic)
    %w(address netmask).each do |key|
      raise "#{key} is required for static interfaces" if new_resource.send(key).nil?
    end
  end
  node.run_state[:lxc] ||= Mash.new
  node.run_state[:lxc][:interfaces] ||= Mash.new
  node.run_state[:lxc][:interfaces][new_resource.container] ||= []
end

action :create do
  raise 'Device is required for creating an LXC interface!' unless new_resource.device
  
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
  end

  net_set = Mash.new(:device => new_resource.device)
  if(new_resource.dynamic)
    net_set[:dynamic] = true
  else
    net_set[:auto] = new_resource.auto
    net_set[:address] = new_resource.address
    net_set[:gateway] = new_resource.gateway
    net_set[:netmask] = new_resource.netmask
    net_set[:up] = new_resource.up if new_resource.up
    net_set[:down] = new_resource.down if new_resource.down
    net_set[:ipv6] = new_resource.ipv6
  end

  node.run_state[:lxc][:interfaces][new_resource.container] << net_set
end

action :delete do
  # do nothing, simply not provided to run_state, and thus implicitly
  # deleted
end
