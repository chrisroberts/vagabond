actions :create, :delete
default_action :create

attribute :container, :kind_of => String, :required => true
attribute :file_system, :kind_of => String, :required => true
attribute :mount_point, :kind_of => String, :required => true
attribute :type, :kind_of => String, :required => true
attribute :options, :kind_of => [String, Array]
attribute :dump, :kind_of => Numeric, :default => 0
attribute :pass, :kind_of => Numeric, :default => 0
attribute :auto_join_rootfs_mount, :kind_of => [TrueClass,FalseClass], :default => true
attribute :create_mount_point, :kind_of => [TrueClass,FalseClass], :default => true
