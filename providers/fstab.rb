def load_current_resource
  if(new_resource.auto_join_rootfs_mount)
    new_resource.mount_point(
      ::Lxc.new(new_resource.container).rootfs.join(
        new_resource.mount_point
      ).to_path
    )
  end
  node.run_state[:lxc] ||= Mash.new
  node.run_state[:lxc][:fstabs] ||= Mash.new
  node.run_state[:lxc][:fstabs][new_resource.container] ||= []
end

action :create do

  line = "#{new_resource.file_system}\t#{new_resource.mount_point}\t" <<
    "#{new_resource.type}\t#{Array(new_resource.options).join(',')}\t" <<
    "#{new_resource.dump}\t#{new_resource.pass}"

  if(new_resource.create_mount_point)
    directory new_resource.mount_point do
      recursive true
    end
  end
  
  unless(node.run_state[:lxc][:fstabs][new_resource.container].include?(line))
    node.run_state[:lxc][:fstabs][new_resource.container] << line
  end

end
