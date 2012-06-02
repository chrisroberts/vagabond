def load_current_resource
  if(new_resource.service_name.to_s.empty?)
    new_resource.service_name new_resource.name
  end
end

action :start do
  execute "lxc start[#{new_resource.service_name}]" do
    command "lxc-start -n #{new_resource.service_name} -d"
    only_if do
      Lxc.exists?(new_resource.service_name) &&
      Lxc.stopped?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :stop do
  execute "lxc stop[#{new_resource.service_name}]" do
    command "lxc-stop -n #{new_resource.service_name}"
    only_if do
      Lxc.exists?(new_resource.service_name) &&
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :restart do
  execute "lxc restart[#{new_resource.service_name}]" do
    command "lxc-restart -n #{new_resource.service_name}"
    only_if do
      Lxc.exists?(new_resource.service_name) &&
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :shutdown do
  execute "lxc shutdown[#{new_resource.service_name}]" do
    command "lxc-shutdown -n #{new_resource.service_name}"
    only_if do
      Lxc.exists?(new_resource.service_name) &&
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :freeze do
  execute "lxc freeze[#{new_resource.service_name}]" do
    command "lxc-freeze -n #{new_resource.service_name}"
    only_if do
      Lxc.exists?(new_resource.service_name) &&
      Lxc.running?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end

action :unfreeze do
  execute "lxc unfreeze[#{new_resource.service_name}]" do
    command "lxc-unfreeze -n #{new_resource.service_name}"
    only_if do
      Lxc.exists?(new_resource.service_name) &&
      Lxc.frozen?(new_resource.service_name)
    end
  end
  new_resource.updated_by_last_action(true)
end
