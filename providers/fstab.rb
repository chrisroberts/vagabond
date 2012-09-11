def load_current_resource
  @loaded ||= {}
  node[:lxc][:fstabs][new_resource.container] ||= []
end

action :create do
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
    template File.join(Lxc.container_path(new_resource.container), 'fstab') do
      source 'fstab.erb'
      mode 0644
      variable :container => new_resource.container
      subscribes :create, resources(:lxc_fstab => new_resource.name), :delayed
    end
  end

  line = "#{new_resource.file_system}\t#{new_resource.mount_point}\t" <<
    "#{new_resource.type}\t#{Array(new_resource.options).join(' ')}\t" <<
    "#{new_resource.dump}\t#{Array(new_resource.pass}"
  unless(node[:lxc][:fstabs][new_resource.container].include?(line))
    node[:lxc][:fstabs][new_resource.container] << line
    new_resource.updated_by_last_action(true)
  end

end

action :delete do
  unless(@loaded[new_resource.container])
    @loaded[new_resource.container] = true
    template File.join(Lxc.container_path(new_resource.container), 'fstab') do
      source 'fstab.erb'
      mode 0644
      variable :container => new_resource.container
      subscribes :create, resources(:lxc_fstab => new_resource.name), :delayed
    end
  end

  line = "#{new_resource.file_system}\t#{new_resource.mount_point}\t" <<
    "#{new_resource.type}\t#{Array(new_resource.options).join(' ')}\t" <<
    "#{new_resource.dump}\t#{Array(new_resource.pass}"
  if(node[:lxc][:fstabs][new_resource.container].include?(line))
    node[:lxc][:fstabs][new_resource.container].delete(line)
    new_resource.updated_by_last_action(true)
  end
end
