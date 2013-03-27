def load_current_resource
  new_resource._lxc Lxc.new(
    new_resource.container,
    :base_dir => node[:lxc][:container_directory],
    :dnsmasq_lease_file => node[:lxc][:dnsmasq_lease_file]
  )
  @loaded ||= {}
  node.run_state[:lxc] ||= Mash.new
  node.run_state[:lxc][:fstabs] ||= Mash.new
  node.run_state[:lxc][:fstabs][new_resource.container] ||= []
end

action :create do

  line = "#{new_resource.file_system}\t#{new_resource.mount_point}\t" <<
    "#{new_resource.type}\t#{Array(new_resource.options).join(',')}\t" <<
    "#{new_resource.dump}\t#{new_resource.pass}"

  unless(node.run_state[:lxc][:fstabs][new_resource.container].include?(line))
    node.run_state[:lxc][:fstabs][new_resource.container] << line
  end

end
