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

Lots of commands. What to see them all? Just ask:

```
$ vagabond --help
Nodes:
        vagabond create NODE [options]
        vagabond destroy NODE [options]
        vagabond freeze NODE [options]
        vagabond provision NODE [options]
        vagabond rebuild NODE [options]
        vagabond ssh NODE [options]
        vagabond start NODE [options]
        vagabond status NODE [options]
        vagabond thaw NODE [options]
        vagabond up NODE [options]
Server:
        vagabond server auto_upload [options]
        vagabond server create [options]
        vagabond server destroy [options]
        vagabond server freeze [options]
        vagabond server provision [options]
        vagabond server rebuild [options]
        vagabond server ssh [options]
        vagabond server start [options]
        vagabond server status [options]
        vagabond server stop [options]
        vagabond server thaw [options]
        vagabond server up [options]
        vagabond server upload_cookbooks [options]
        vagabond server upload_databags [options]
        vagabond server upload_environments [options]
        vagabond server upload_roles [options]
Options:
        --debug
        --disable-auto-provision
        --disable-local-server
        --disable-configure
        --force-configure
    -f, --vagabond-file FILE
```

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

This is still very much in alpha testing phase. So if you find bugs, please
report them!

## Contributing

No hard and fast rules for contributing just preferences. I'm always happy to 
get help making things better!

* Base updates and pull requests on the `develop` branch
* Please don't update core files like `version.rb` or `vagabond.gemspec`

## Infos

* Repository: https://github.com/chrisroberts/vagabond