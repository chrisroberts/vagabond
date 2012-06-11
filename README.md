Example Recipe:

```ruby

include_recipe 'lxc'

lxc_container 'chef_test' do
  action :create
  validation_client 'chrisroberts-validator'
  server_uri 'https://api.opscode.com/organizations/chrisroberts'
  run_list %w(role[precise])
  chef_enabled true
end

lxc_container 'chef_test_next' do
  action :clone
  base_container 'chef_test'
  chef_enabled true
end

lxc_service 'chef_test_next' do
  action :start
end
```

and attributes:

```ruby

override_attributes(
  :lxc => {
    :validator_pem => "PEM HERE"
  }
)

```

The validator pem is required to register containers. This can be encrypted via 
bag_config, or we can just keep it in a specific data bag, or something else.
