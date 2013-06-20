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
