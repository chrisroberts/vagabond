# Vagabond

* Issue: VMs are slow. Especially when creating over and over.
* Discovery: Linux provides LXC tools similar to BSD jails
* Helpful: LXCs can provide different distributions
* Implementation: Vagabond

Awesome

## What is this thing?

Vagabond is a tool integrated with Chef to build local nodes
easily and most importantly, quickly. It uses Linux containers
instead of full blown VMs which means things are faster. Lots
faster.

## How it is?

Currently, this is built to run within a classic Chef repository.
It requires a Vagabond file, that simply outputs a Hash. The file
is Ruby though, so you can do lots of crazy stuff to build the
Hash you return. Heres a simple example:

```ruby
{
  :boxes => {
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

Pretty simple, right?

## Commands

```
# create and provision
$ vagabond up NODE

# provision existing
$ vagabond provision NODE

# freeze (pause) node
$ vagabond freeze NODE

# thaw (unpause) node
$ vagabond thaw NODE

# destroy node
$ vagabond destroy NODE

# status of defined nodes
$ vagabond status [NODE]

# ssh to node
$ vagabond ssh NODE
```

## Local chef server?

Yep, that's right. You can let vagabond set you up with a local chef
server hanging out in a container, which all your vagabond nodes can
then run against. Isolated building and testing? You betcha!

Server containers are isolated by project. This means you will have an
erchef instance running in an isolated container for every project the
local server option is enabled. It's just an important bit of information
to remember so you can make a mental note to stop or freeze it when not
in use.

Server provides a superset of the commands available for regular
vagabond nodes. They are accessed using:

`$ vagabond server COMMAND`

## Important note

Until namespaces hit Linux proper, vagabond `sudo`s its way around. You
_can_ get around this using the setcap stuff, but it's pretty meh. If you
do go that road, just turn off `sudo` in your Vagabond file by setting
`:sudo => false`.

## Extra note

This is still very much in alpha testing phase. So if you find bugs, please
report them!

## Infos

* Repository: https://github.com/chrisroberts/vagabond