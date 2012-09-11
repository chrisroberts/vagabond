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

  ruby_block "lxc start[#{new_resource.service_name}]" do
    block do
      new_resource._lxc.start
    end
    only_if do
      !new_resource._lxc.running? && new_resource.updated_by_last_action(true)
    end
  end

end

action :halt do
  ruby_block "lxc halt[#{new_resource.service_name}]" do
    block do
      new_resource._lxc.stop
    end
    only_if do
      new_resource._lxc.running? && new_resource.updated_by_last_action(true)
    end
  end
end

# TODO: Should we wait for stop and then wait for start here?
action :restart do
  ruby_block "lxc restart[#{new_resource.service_name}]" do
    block do
      new_resource._lxc.shutdown
      new_resource._lxc.start
    end
    only_if do
      new_resource._lxc.running? && new_resource.updated_by_last_action(true)
    end
  end
end

action :stop do
  ruby_block "lxc stop[#{new_resource.service_name}]" do
    block do
      new_resource._lxc.shutdown
    end
    only_if do
      new_resource._lxc.running? && new_resource.updated_by_last_action(true)
    end
  end
end

action :freeze do
  ruby_block "lxc freeze[#{new_resource.service_name}]" do
    ruby_block do
      new_resource._lxc.freeze
    end
    only_if do
      new_resource._lxc.running? && new_resource.updated_by_last_action(true)
    end
  end
end

action :unfreeze do
  ruby_block "lxc unfreeze[#{new_resource.service_name}]" do
    block do
      new_resource._lxc.unfreeze
    end
    only_if do
      new_resource._lxc.frozen? && new_resource.updated_by_last_action(true)
    end
  end
end
