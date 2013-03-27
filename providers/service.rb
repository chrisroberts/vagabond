def load_current_resource
  @lxc = ::Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  if(new_resource.service_name.to_s.empty?)
    new_resource.service_name new_resource.name
  end
end

action :start do
  if(@lxc.stopped?)
    @lxc.start
    new_resource.updated_by_last_action(true)
  end
end

action :halt do
  if(@lxc.running?)
    @lxc.stop
    new_resource.updated_by_last_action(true)
  end
end

action :restart do
  if(@lxc.running?)
    @lxc.shutdown
  end
  @lxc.start
  new_resource.updated_by_last_action(true)
end

action :stop do
  if(@lxc.running?)
    @lxc.stop
    new_resource.updated_by_last_action(true)
  end
end

action :freeze do
  if(@lxc.running?)
    @lxc.freeze
    new_resource.updated_by_last_action(true)
  end
end

action :unfreeze do
  if(@lxc.frozen?)
    @lxc.unfreeze
    new_resource.updated_by_last_action(true)
  end
end
