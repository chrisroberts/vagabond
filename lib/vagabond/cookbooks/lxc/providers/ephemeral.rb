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
end

action :run do
  com = ['lxc-ephemeral-start']
  com << "-o #{new_resource.base_container}"
  com << "-b #{new_resource.bind_directory}" if new_resource.bind_directory
  com << "-U #{new_resource.union_type}"
  com << "-u #{new_resource.user}"
  com << "-S #{new_resource.key}"
  if(new_resource.background)
    Chef::Log.warn("Ephemeral container will be backgrounded: #{new_resource.name}")
    com << '-d'
  end
  com << new_resource.command
  execute "LXC ephemeral: #{new_resource.name}" do
    command com.join(' ')
  end
end
