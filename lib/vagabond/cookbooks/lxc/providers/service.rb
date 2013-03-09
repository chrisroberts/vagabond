def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  if(new_resource.service_name.to_s.empty?)
    new_resource.service_name new_resource.name
  end
end

action :start do
  if(new_resource._lxc.stopped?)
    new_resource._lxc.start
    new_resource.updated_by_last_action(true)
  end
end

action :halt do
  if(new_resource._lxc.running?)
    new_resource._lxc.stop
    new_resource.updated_by_last_action(true)
  end
end

action :restart do
  if(new_resource._lxc.running?)
    new_resource._lxc.shutdown
  end
  new_resource._lxc.start
  new_resource.updated_by_last_action(true)
end

action :stop do
  if(new_resource._lxc.running?)
    new_resource._lxc.stop
    new_resource.updated_by_last_action(true)
  end
end

action :freeze do
  if(new_resource._lxc.running?)
    new_resource._lxc.freeze
    new_resource.updated_by_last_action(true)
  end
end

action :unfreeze do
  if(new_resource._lxc.frozen?)
    new_resource._lxc.unfreeze
    new_resource.updated_by_last_action(true)
  end
end
