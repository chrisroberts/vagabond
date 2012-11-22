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
