Example Recipe:

```ruby

include_recipe 'lxc'

lxc_container 'chef_test' do
  action :create
  validation_client 'chrisroberts-validator'
  server_uri 'https://api.opscode.com/organizations/chrisroberts'
  run_list %w(role[precise])
end

lxc_container 'chef_test_next' do
  action :clone
  base_container 'chef_test'
end

lxc_service 'chef_test_next' do
  action :start
end
```

and attributes:

```ruby

override_attributes(
  :lxc => {
    :start_ipaddress => '10.0.3.2',
    :validator_pem => "PEM HERE"
  }
)

```

Right now the start_ipaddress is required because stuff is lazy and uses
what ubuntu provides up front to get things working. The validator pem is
required to register containers. This can be encrypted via bag_config, or
we can just keep it in a specific data bag, or something else.
