## v0.2.10
* Fix `:berkshelf` key to be optionally Hash type
* Allow all types for roles/environments/data bags
* Add guards for uploads of file types (thanks @jaypipes)
* Raise exception on failed provisions
* Force utf-8 on all files
* Better output on parallel cluster builds
* Use Librarian to vendor internal cookbooks at runtime
* Provide `spec` support within isolated cookbooks (outside of chef-repo)
* Make `server` nodes ephemeral
* Build base erchef server containers with versions
* Customize host provisioning cookbook versions based on dev/release version
* Added callbacks
* Allow passing commands to nodes via `ssh` action
* Lots of cleanup and other stuff that's not jumping out of the git history

## v0.2.8
* Disable `chef-server` clone on provision (#14)
* Temporarily disable provision on init action
* Use a cacher for apt

## v0.2.6
* Better use of `store_path` for working in standalone cookbooks
* Always vendor cookbooks when resolving, use knife to upload
* Clean up cluster test-kitchen support. Only resolve cookbooks once when in cluster mode
* Use `update` if `install` has already been preformed with librarian
* Add node name validation smarts to short circuit if action does not require it

## v0.2.4
* Use correct sudo within provision action
* Fix options helper in `destroy` (implicitly fixes `cluster` options)
* Only print full help if help is the only argument received

## v0.2.2
* Migration to elecksee gem for LXC management
* Addition of chef-zero support for local chef server
* Updated testing for standalone cookbook testing
* Updated support for dependency resolvers (librarian and berkshelf)
* Addition of `spec` support
* Better isolation around sudo usage
* Cleaned `internal_configuration` and added automatic reloading on detected changes
* Added `cluster` support to Vagabondfile for easily building multiple nodes
* New `init` command for base setup
* Lots and lots of bug fixes and feature enhancements
* Output relevant information on bad command
* Huge thanks to all those that helped test, debug, and add features especially:
  * Jesse Nelson - https://github.com/spheromak
  * Bryan Berry - https://github.com/bryanwb
  * Sean Escriva - https://github.com/webframp


## v0.2.0
* Migrate to thor
* Clean up option usage
* Add support for custom template builds
* DRY out some reusable stuffs
* Change Vagabondfile key :boxes to :nodes
* Start on defined color codes for actions/states (not implemented)
* Add some validation and error checking
* Make server stuff work better
* Add integrated support for test kitchen 1.0
* Add new 'cluster' support for test kitchen 1.0

## v0.1.4
* Fix color option to do the right thing

## v0.1.2
* Added support for centos guests
* Added new base templates for centos and debian
* Debugging output support
* Pretty CLI output
* Actual help output
* Improved status output
* SSH functionality to nodes
* Improved server functionality
* Other stuff I probably forgot

## v0.1.0
* Initial release!
