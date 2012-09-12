def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.container,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  @loaded ||= {}
  node[:lxc][:fstabs] ||= Mash.new
  node[:lxc][:fstabs][new_resource.container] ||= []
end

action :create do
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
    ruby_block "lxc_fstab_notifier[#{new_resource.container}]" do
      action :create
      block{ true }
      only_if do
        new_resource.updated_by_last_action?
      end
    end
    template ::File.join(new_resource._lxc.container_path, 'fstab') do
      source 'fstab.erb'
      mode 0644
      variables :container => new_resource.container
      subscribes :create, resources(:ruby_block => "lxc_fstab_notifier[#{new_resource.container}]"), :delayed
    end
  end

  line = "#{new_resource.file_system}\t#{new_resource.mount_point}\t" <<
    "#{new_resource.type}\t#{Array(new_resource.options).join(',')}\t" <<
    "#{new_resource.dump}\t#{new_resource.pass}"
  unless(node[:lxc][:fstabs][new_resource.container].include?(line))
    node[:lxc][:fstabs][new_resource.container] << line
    new_resource.updated_by_last_action(true)
  end

end

action :delete do
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
    
    ruby_block "lxc_fstab_notifier[#{new_resource.container}]" do
      action :create
      block{ true }
      only_if do
        new_resource.updated_by_last_action?
      end
    end

    template ::File.join(new_resource._lxc.container_path, 'fstab') do
      source 'fstab.erb'
      mode 0644
      variables :container => new_resource.container
      subscribes :create, resources(:ruby_block => "lxc_fstab_notifier[#{new_resource.container}]"), :delayed
    end
  end

  line = "#{new_resource.file_system}\t#{new_resource.mount_point}\t" <<
    "#{new_resource.type}\t#{Array(new_resource.options).join(' ')}\t" <<
    "#{new_resource.dump}\t#{new_resource.pass}"
  if(node[:lxc][:fstabs][new_resource.container].include?(line))
    node[:lxc][:fstabs][new_resource.container].delete(line)
    new_resource.updated_by_last_action(true)
  end
end
