# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.hostname = "vagabond-lxc-host"

  unless(ENV['DISABLE_PRESEED'])
    config.vm.box = 'precise-64-lxc-preseed'
    config.vm.box_url = 'http://vagrant.hw-ops.com/precise-64-lxc-preseed.box'
  else
    config.vm.box = 'precise-64'
    config.vm.box_url = 'https://github.com/downloads/chrisroberts/vagrant-boxes/precise-64.box'
  end

  if(ENV['ENABLE_APT_PROXY'])
    proxy = [
      "echo \"Acquire::http::Proxy \\\"http://#{ENV['ENABLE_APT_PROXY']}:3142\\\";\" > /etc/apt/apt.conf.d/01proxy",
      "echo \"Acquire::https::Proxy \\\"DIRECT\\\";\" >> /etc/apt/apt.conf.d/01proxy"
    ]
  else
    proxy = []
  end

  config.vm.provision :shell do |shell|
    shell.inline = (
      proxy + [
        "lxc-destroy -n ubuntu_1204",
        "apt-get update",
        "apt-get install -y -q python-software-properties git build-essential",
        "add-apt-repository ppa:brightbox/ruby-ng",
        "apt-get update",
        "apt-get install -y -q ruby1.9.1 ruby1.9.1-dev",
        "gem install --no-ri --no-rdoc bundler",
        "cd /home/vagrant",
        %(echo "source 'https://rubygems.org'\ngem 'vagabond', path: '/vagrant'\n" > Gemfile),
        "bundle install --binstubs"
      ]
    ).join("\n")
  end

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--cpus", "2"]
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end
end
