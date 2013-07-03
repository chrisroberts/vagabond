# Vagabond USAGE

## Requirements

* Chef repository structure
* Ubuntu >= 12.04
  * This requirement is soft. It is only here because it is the only place it has currently been tested. Testing on centos, debian, and arch is coming soon.

## Setup

* Install vagabond either in a Gemfile, or via gem:

```
$ gem install vagabond
```

Drop a Vagabondfile in the root of your Chef repository. Here is a
very simple Vagabond file to start with:

```ruby
{
  :nodes => {
    :my_precise_node => {
      :template => 'ubuntu_1204',
      :run_list => ['role[base]']
    }
  }
}
```

This assumes you have a role named base, and that it and its dependencies
are currently pushed up to your configured chef server. So, we create our
node:

```
$ vagabond up my_precise_node
```

The first time this runs, it will take some time. Vagabond will provision
your local system (using chef-solo) to install the required LXC tools, and
to build the templates in use by your Vagabond file. Vagabond will do
this any time it determines it's required, generally when new templates
are discovered that does not already have a base container built. So sit
back, the first build will take a few.

## Custom templates

Custom templates are templates that are based on the builtin templates
but have some restriction placed on them, for example memory usage. Using
our current Vagabond file example, lets say we wanted to use a container
that only had 512MB of memory available to it, and no swap space. We
would provide the details for a custom template, and set the `my_precise_node`
to then use that template:


```ruby
{
  :nodes => {
    :my_precise_node => {
      :template => 'custom_1204_512',
      :run_list => ['role[base]']
    }
  },
  :templates => {
    :custom_1204_512 => {
      :base => 'ubuntu_1204',
      :memory => {
        :ram => '512M',
        :swap => 0
      }
    }
  }
}
```

## Assigning static IP addresses to nodes

Nodes can be assigned static IP addresses using the `:ipaddress` key in
the node's Hash:

```ruby
{
  :nodes => {
    :my_precise_node => {
      :template => 'ubuntu_1204',
      :run_list => ['role[base]'],
      :ipaddress => '10.0.0.10'
    }
  }
  ...
```

## vagabond

The `vagabond` command is used for interaction with nodes. Simply running:

```
$ vagabond
```

will provide a list of available actions.

## vagabond ssh

This tool just provides an easy way to SSH into running nodes. Just
provide the name and it will drop you into a root session:

```
$ vagabond ssh my_precise_node
```

## vagabond server

Vagabond will optionally allow the installation of a chef server that is
localized to the chef repository the Vagabondfile is kept within. This 
is enabled in the Vagabondfile. To do this, our Vagabondfile would now
look like this:

```ruby
{
  :nodes => {
    :my_precise_node => {
      :template => 'ubuntu_1204',
      :run_list => ['role[base]']
    }
  },
  :local_chef_server => {
    :enabled => true
  }
}
```

The next command run will trigger vagabond to reprovision and will create
a server container. The chef server will be auto configured using your
existing client information. It will seamlessly take over while using
Vagabond. The server commands are explicitly for the server container.
The commands are similar to the basic `vagabond` commands, with a few
extra commands as well.

The `:local_chef_server` hash has a few helper keys for setting up
the server:

* `:auto_upload` - Uploads all cookbooks, roles, data bags and environments after build
* `:berkshelf` - Uses berkshelf for cookbook upload instead of knife
* `:librarian` - Uses librarian for cookbook upload instead of knife
* `:zero` - Uses Chef Zero instead of Chef 11 (erchef)

## vagabond knife

This tool will let you communicate with the chef server provided by Vagabond.
Just pass arguments to it like you would knife regularly, and they will 
be set to the local chef server instead:

```
$ vagabond knife cookbook list
```

# Testing

Vagabond has built in support for test-kitchen 1.0. However, it does things
just a little bit differently. First, it will map the platform defined to an lxc
template. Second, it will use Librarian to resolve dependencies for the
cookbook and use those for testing. 

Usage is straightforward:

```
$ vagabond kitchen test COOKBOOK
```

You can limit what you test at once by providing `--platform` and/or `--suites`
options to the test. Tests are run the same was as t-k 1.0. Run lists will be
merged, attributes pushed to the node, and solo to provision the node.

## Clusters

Vagabond offers an extra type of testing. Instead of simply providing an isolated
place to test a cookbook (on a single node), Vagabond allows you to run tests against
a cluster of nodes, with a real chef server. This allows for real integration testing
within a real isolated environment. Multiple nodes. Real Chef server. A real environment
that can properly test the behavior of an infrastructure. 

## How it works

Currently, Vagabond adds an extra key the `.kitchen.yml` file of a cookbook. It's
the `clusters` key. It's a simple hash. The keys are the names of the cluster. The
values are arrays of strings that identify the suites to be built for the cluster.
A simple example looks like this:

```
clusters:
  default:
    - cool_suite1
    - cool_suite2
```

And now, we can spin this up doing:

```
$ vagabond kitchen test COOKBOOK --cluster default --platform ubuntu-12.04
```

First, this will restrict our testing to just the ubuntu-12.04 platform. Next
it will upload all assets to the local chef server. It then provisions two
nodes. First it provisions cool_suite1. Next it provisions cool_suite2. These
nodes are defined by their configuration in the suites. After the nodes
have successfully provisioned, test kitchen is then run on each of the nodes
in the cluster sequentially.

Simple, yet so very very awesome. \o/

## More to come

Testing support is still very young, just like Vagabond. But there are plans
in the works for more features. Take a look at the issues section in github
with `kitchen` tags. Feel free to add more if you see something missing!
