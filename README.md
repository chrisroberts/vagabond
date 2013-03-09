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
$ vagabond up precise

# provision existing
$ vagabond provision precise

# freeze (pause) node
$ vagabond freeze precise

# thaw (unpause) node
$ vagabond thaw node

# destroy node
$ vagabond destroy precise

# status of defined nodes
$ vagabond status [node]

# ssh to node
$ vagabond ssh precise

## Local chef server?

Yep, that's right. You can let vagabond set you up with a local chef
server hanging out in a container, which all your vagabond nodes can
then run against. Isolated building and test? You betcha!

Server provides a superset of the commands available for regular
vagabond nodes. They are accessed using:

`$ vagabond server COMMAND`

## Important note

Until namespaces hit Linux proper, vagabond `sudo`s its way around. You
_can_ get around this using the setcap stuff, but it's pretty meh. If you
do go that road, just turn off `sudo` in your Vagabond file by setting
`:sudo => false`.

## Infos

* Repository: https://github.com/chrisroberts/vagabond