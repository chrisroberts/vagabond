actions :run
default_action :run

attribute :command, :kind_of => String, :required => true
attribute :bind_directory, :kind_of => String
attribute :base_container, :kind_of => String, :required => true
attribute :background, :kind_of => [TrueClass,FalseClass], :default => false
attribute :union_type, :equal_to => %w(aufs overlayfs), :default => 'overlayfs'
attribute :user, :kind_of => String, :default => 'root'
attribute :key, :kind_of => String, :default => '/opt/hw-lxc-config/id_rsa'
attribute :host_rootfs, :kind_of => String
attribute :virtual_device, :kind_of => Numeric
attribute :stream_output, :kind_of => [TrueClass,FalseClass,IO]
