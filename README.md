## LXC

Manage linux containers with Chef.

### Recipes

#### default

Installs the packages and configuration files needed for lxc on the server.

#### install_dependencies

Installs the packages needed to support lxc's containers.

#### knife

Install and manage the knife-lxc plugin.

### Example

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

Containers do not have to be Chef enabled but it does make them
extremely easy to configure. If you want the Omnibus installer
cached, you can set the attribute

```ruby
node['omnibus_updater']['cache_omnibus_installer'] = true
```

in a role or environment (default is false). The `lxc_container`
resource also provides `initialize_commands` which an array of
commands can be provided that will be run after the container is
created.

### Repository:

* https://github.com/hw-cookbooks/lxc

### Contributors

* Sean Porter (https://github.com/portertech)
* Matt Ray (https://github.com/mattray)
