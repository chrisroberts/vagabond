actions :create, :delete, :clone
default_action :create

attribute :base_container, :kind_of => String
attribute :validation_client, :kind_of => String
attribute :validator_pem, :kind_of => String, :default => nil
attribute :server_uri, :kind_of => String
attribute :node_name, :kind_of => String
attribute :run_list, :kind_of => Array
attribute :chef_enabled, :kind_of => [TrueClass, FalseClass], :default => true
attribute :chef_retries, :kind_of => Fixnum, :default => 0
attribute :copy_data_bag_secret_file, :kind_of => [TrueClass, FalseClass], :default => false
attribute :data_bag_secret_file, :kind_of => String, :default => Chef::EncryptedDataBagItem::DEFAULT_SECRET_FILE
attribute :default_bridge, :kind_of => String
attribute :static_ip, :kind_of => String
attribute :static_netmask, :kind_of => String, :default => '255.255.255.0'
attribute :static_gateway, :kind_of => String
attribute :default_config, :kind_of => [TrueClass, FalseClass], :default => true
attribute :default_fstab, :kind_of => [TrueClass, FalseClass], :default => true
attribute :container_commands, :kind_of => Array, :default => []
attribute :initialize_commands, :kind_of => Array, :default => []
attribute :new_container, :kind_of => [TrueClass, FalseClass], :default => false
attribute :template, :equal_to => %w(fedora debian ubuntu ubuntu-cloud), :default => 'ubuntu'
attribute :_lxc
# TODO: We should ultimately have support for all these templates
#attribute :template, :equal_to => %w(busybox debian fedora opensuse sshd ubuntu ubuntu-cloud), :default => 'ubuntu'
