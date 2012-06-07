def load_current_resource
  if(new_resource.service_name.to_s.empty?)
    new_resource.service_name new_resource.name
  end
end

action :start do

  ruby_block "lxc start[#{new_resource.service_name}]" do
    block do
      Lxc.start(new_resource.service_name)
    end
    not_if do
      Lxc.running?(new_resource.service_name)
    end
  end

  new_resource.updated_by_last_action(true)
end

action :stop do
  ruby_block "lxc stop[#{new_resource.service_name}]" do
    block do
      Lxc.stop(new_resource.service_name)
    end
    only_if do
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

# TODO: Should we wait for stop and then wait for start here?
action :restart do
  execute "lxc restart[#{new_resource.service_name}]" do
    command "lxc-restart -n #{new_resource.service_name}"
    only_if do
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :shutdown do
  ruby_block "lxc shutdown[#{new_resource.service_name}]" do
    block do
      Lxc.shutdown(new_resource.service_name)
    end
    only_if do
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :freeze do
  ruby_block "lxc freeze[#{new_resource.service_name}]" do
    ruby_block do
      Lxc.freeze(new_resource.service_name)
    end
    only_if do
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :unfreeze do
  ruby_block "lxc unfreeze[#{new_resource.service_name}]" do
    block do
      Lxc.unfreeze(new_resource.service_name)
    end
    only_if do
      Lxc.frozen?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end
