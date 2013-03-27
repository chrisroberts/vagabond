def load_current_resource
  @lxc = ::Lxc.new(
    new_resource.name,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
end

action :create do
  _lxc = @lxc
  execute "LXC Create: #{new_resource.name}" do
    command "lxc-create -n #{new_resource.name} -t #{new_resource.template} -- #{new_resource.template_opts.to_a.flatten.join(' ')}"
    only_if do
      !_lxc.exists? && new_resource.updated_by_last_action(true)
    end
  end
end

action :clone do
  _lxc = @lxc
  _base_lxc = ::Lxc.new(
    new_resource.base_container,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )

  unless(_base_lxc.exists?)
    raise "LXC clone failed! Base container #{new_resource.base_container} does not exist. Cannot create #{new_resource.name}"
  end
  
  execute "LXC Clone: #{new_resource.base_container} -> #{new_resource.name}" do
    command "lxc-clone -o #{new_resource.base_container} -n #{new_resource.name}"
    only_if do
      !_lxc.exists? && new_resource.updated_by_last_action(true)
    end
  end

end

action :delete do
  _lxc = @lxc
  ruby_block "Stop container #{new_resource.name}" do
    block do
      _lxc.shutdown
    end
    only_if do
      _lxc.exists? && _lxc.running?
    end
  end

  execute "Destroy container #{new_resource.name}" do
    command "lxc-destroy #{new_resource.name}"
    only_if do
      _lxc.exists?
    end
  end
end
