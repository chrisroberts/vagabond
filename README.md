LXC
===

Manage linux containers with Chef.

Example
--------

```ruby
include_recipe 'lxc'

lxc_container 'my_container' do
  action :create
  validation_client 'my-validator'
  server_uri 'https://api.opscode.com/organizations/myorg'
  validator_pem content_from_encrypted_dbag
  run_list ['role[base]']
  chef_enabled true
end

lxc_container 'my_container_clone' do
  action :clone
  base_container 'my_container'
  chef_enabled true
end

lxc_service 'my_container_clone' do
  action :start
end
```

Containers do not have to be chef enabled but it does make them
extremely easy to configure. The lxc_resource container also provides
`initialize_commands` which an array of commands can be provided
that will be run after the container is created.

Repository:

* https://github.com/hw-cookbooks/lxc
