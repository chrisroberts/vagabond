# Hacking Vagabond

Here's some useful notes about hacking on Vagabond

## Git branch

Unstable development is on the `develop` branch. Pull requests should
be based on the `develop` branch and any changes will be merged there
prior to being merged into `master`. The `master` branch will always
be the currently stable released version.

## Versioning

Stable versions will always be even numbered patch levels. Unstable
versions will always be odd numbered patch levels.

### Unstable behavior

When unstable versions are detected vagabond will provision the system
differently than when within stable versions. The Cheffile used to vendor
cookbooks for provisioning the host will use cookbook linked to unstable
versions of the cookbooks, and these will be updated every hour.

Since stable versions of vagabond will link directly to released versions
of cookbooks, a single update to pull the dependencies is sufficient. In
development mode with cookbooks linked to changing cookbooks, getting updates
will be required as the code is updated.

## Debugging

Vagabond will not print stacktraces by default when an error is encountered.
To enable stacktraces on errors, set the environment variable `VAGABOND_EXIT_DEBUG`
prior to running a command. Alternatively you can export the variable so it
will always be set:

```
$ export VAGABOND_EXIT_DEBUG=true
```