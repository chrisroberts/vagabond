use_inline_resources if self.respond_to?(:use_inline_resources)

def load_current_resource
  @lxc = ::Lxc.new(
    new_resource.base_container,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  unless(@lxc.exists?)
    raise "Requested base contianer: #{new_resource.base_container} does not exist"
  end
  @start_script = node[:lxc][:awesome_ephemerals] ? '/usr/local/bin/lxc-awesome-ephemeral' : 'lxc-ephemeral-start'
  unless(node[:lxc][:awesome_ephemerals])
    %w(host_rootfs virtual_device).each do |key|
      if(resource.send(key))
        raise "#{key} lxc ephemeral attribute only valid when awesome_ephemerals is true!"
      end
    end
  end
end

action :run do
  com = [@start_script]
  com << "-o #{new_resource.base_container}"
  com << "-b #{new_resource.bind_directory}" if new_resource.bind_directory
  com << "-U #{new_resource.union_type}"
  com << "-u #{new_resource.user}"
  com << "-S #{new_resource.key}"
  com << "-z #{new_resource.host_rootfs}" if new_resource.host_rootfs
  com << "-D #{new_resource.virtual_device}" if new_resource.virtual_device 
  if(new_resource.background)
    Chef::Log.warn("Ephemeral container will be backgrounded: #{new_resource.name}")
    com << '-d'
  end
  com << "\"#{new_resource.command}\"" # TODO: fix this to be proper
  execute "LXC ephemeral: #{new_resource.name}" do
    command com.join(' ')
    stream_output new_resource.stream_output
  end
end
