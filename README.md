# Vagabond

* Issue: VMs are slow.
* Discovery: Linux has LXC, which is pretty cool.
* Helpful: LXCs can run different distributions.
* Implementation: Vagabond

Awesome

## What is this thing?

Vagabond is a tool integrated with Chef to build local nodes
easily and most importantly, quickly. It uses Linux containers
instead of full blown VMs which means things are faster. Lots
faster.

Vagabond is built for Chef. The tooling within Vagabond is targeted
at Chef. As the initial development push on Vagabond slows, this
tooling will become optionally swappable (applicable bits at least).

## Installation

As a rubygem:

```
$ gem install vagabond
```

## How does it work

Currently, this is built to run within a classic Chef repository.
It requires a `Vagabond` file, that simply outputs a Hash. The file
is Ruby though, so you can do lots of crazy stuff to build the
Hash you return. Heres a simple example:

```ruby
{
  :nodes => {
    :precise => {
      :template => 'ubuntu_1204',
      :run_list => %w(role[base])
    },
    :db => {
      :template => 'ubuntu_1204',
      :run_list => %w(role[db])
    }
  },
  :local_chef_server => {
    :enabled => true,
    :auto_upload => true
  }
}
```

Now, to create a node, simply run:

```
$ vagabond up db
```

Pretty simple, right?

### Templates available

Currently builtin templates:

* ubuntu_1204
* ubuntu_1210
* debian_6
* debian_7
* centos_58
* centos_63
* centos_64

## Commands

See the `USAGE` file for an overview of available commands and their
usage.

## Local chef server?

Yep, that's right. You can let vagabond set you up with a local chef
server hanging out in a container, which all your vagabond nodes can
then run against. Isolated building and testing? You betcha!

Server containers are isolated by project. This means you will have an
erchef instance running in an isolated container for every project the
local server option is enabled. It's just an important bit of information
to remember so you can make a mental note to stop or freeze it when not
in use. Or just let them run. What ever floats your boat.

### Vagabond knife

Since you can have a local chef server running, it can also be helpful
to be able to actually interact with that server. Vagabond has commands
for doing bulk uploads of assets, but you can access it too with knife
to do isolated uploads, or to just do knifey things:

```
vagabond knife SOME COOL KNIFE COMMAND
```

This will just push the command into the local chef server. 

## Test Kitchen

Vagabond provides test kitchen 1.0 support. It will map boxes defined
within platforms to platform templates available (to the best of its
ability). No need to spin up vagrant VMs, or use another tool. Point
vagabond at the cookbook, and let it handle the details.

In the TODO pipeline is allowing platform mapping in the Vagabondfile
so custom templates (with memory limits for example) can be used
instead of the base templates.

### Cluster testing

Vagabond adds an extra feature to test kitchen: cluster testing. This
type of testing uses the local chef server, and provides an extreme
amount of power to tests. Instead of provisioning a node and simply
testing it in isolation, cluster testing provides the support to
provision multiple nodes against the local chef server. Once all
nodes have been successfully provisioned, vagabond will go back through
each node and run tests.

Seems simple, right? It is, but it's also extremely powerful. Instead
of testing things individually and isolated, this allows for real
integration testing. Tests can be applied to discovery, slaving,
and all the other fun things nodes may be doing that require a
chef server. Looking for example? See the `USAGE` file!

Double awesome

## Important note

Until namespaces hit Linux proper, vagabond `sudo`s its way around. You
_can_ get around this using the setcap stuff, but it's pretty meh. If you
do go that road, just turn off `sudo` in your Vagabond file by setting:

```
:sudo => false
```

Oh, and if you use `rvm` and would rather be using `rvmsudo` instead of
boring old `sudo`, you can do that to:

```
:sudo => 'rvmsudo'
```

## Extra note

This thing is still very new and shiny with lots of sharp edges. They
are getting sanded down as quickly as possible. If you find bugs, are
confused about some of the available functionality, or just want to point 
out some stupidity that I have implemented, please file an issue on github!

## Contributing

No hard and fast rules for contributing just preferences. I'm always happy to 
get help making things better!

* Base updates and pull requests on the `develop` branch
* Please don't update core files like `version.rb` or `vagabond.gemspec`

## Infos

* Repository: https://github.com/chrisroberts/vagabond