def initialize(*args)
  super
  @action = :create
end

actions :create, :delete, :clone

attribute :base_container, :kind_of => String
attribute :validation_client, :kind_of => String, :required => true
attribute :validator_pem, :kind_of => String
attribute :server_uri, :kind_of => String, :required => true
attribute :node_name, :kind_of => String
attribute :run_list, :kind_of => Array, :required => true

