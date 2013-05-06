## v1.0.0
* Extract container actions out to new LWRP `lxc`
* Update `container` to use `lxc` resource for container actions
* Update `container` to allow nested subresources for `interface` and `fstab_mount`
* Fix `interface` LWRP to allow IPv6 based values
* Remove static_ip config set as it was introducing bogus route
* Provide assumed environment when not available (like when running via runit)
* Make chef enabled containers properly idempotent
* Clean up the `container` provider implementation to be more resource based
* Add `ephemeral` LWRP
* Add custom ephemeral script to allow host directory overlay or virtual block device
* Patches execute resource to provide streaming output
* Updates Lxc library to be more reusable
* Add proc based network detection for more robust address discovery
* Shell out directly to ssh for container commands instead of using knife ssh

## v0.1.0
* Abstracted out packages for cross-platform support later.
* Added the 'containers' recipe to create containers for the members of the node['lxc']['containers'] hash
* Add support for use of the apt::cacher-client settings if a proxy is in use.
* chef_enabled defaults to false on lxc_containers
* Better idempotency checks when building new containers
* Refactoring of lxc_service
* Container based commands run via knife::ssh providing proper logging feedback
* New networking related attributes added to lxc_container for easy basic network setups

## v0.0.3
* Remove resource for deprecated template

## v0.0.2
* Cleanup current config and container LWRPs
* Add new LWRPs (fstab and interface)
* Add better configuration build to prevent false updates
* Thanks to Sean Porter (https://github.com/portertech) for help debugging LWRP updates

## v0.0.1
* Initial release
