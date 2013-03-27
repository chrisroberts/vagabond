def initialize(*args)
  @subresources = []
  super
end

actions :create, :delete
default_action :create

attribute :base_container, :kind_of => String
attribute :validation_client, :kind_of => String
attribute :validator_pem, :kind_of => String, :default => nil
attribute :server_uri, :kind_of => String
attribute :chef_environment, :kind_of => String, :default => '_default'
attribute :node_name, :kind_of => String
attribute :run_list, :kind_of => Array
attribute :chef_enabled, :kind_of => [TrueClass, FalseClass], :default => false
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
attribute :clone, :kind_of => String
attribute :template, :kind_of => String, :default => 'ubuntu'
attribute :template_opts, :kind_of => Hash, :default => {}
attribute :create_environment, :kind_of => Hash, :default => {}

def fstab(fname=nil, &block)
  instance_eval &block
end

def mount(mname='mount', &block)
  r = self
  stab = lxc_fstab(mname) do
    container r.name
    instance_eval &block
  end
  stab.action :nothing
  @subresources << stab
end

def interface(name=nil, &block)
  instance_eval &block
end

def device(iname='device', &block)
  iface = lxc_interface(iname) do
    container r.name
    instance_eval &block
  end
  iface.action :nothing
  @subresources << iface
end

