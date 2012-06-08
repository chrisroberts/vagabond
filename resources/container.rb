def initialize(*args)
  super
  @action = :create
end

actions :create, :delete, :clone

attribute :base_container, :kind_of => String
attribute :validation_client, :kind_of => String
attribute :validator_pem, :kind_of => String
attribute :server_uri, :kind_of => String
attribute :node_name, :kind_of => String
attribute :run_list, :kind_of => Array
attribute :chef_enabled, :kind_of => [TrueClass, FalseClass], :default => true
attribute :static_ip, :kind_of => String, :default => false
attribute :config, :kind_of => Hash
attribute :container_commands, :kind_of => Array, :default => []
