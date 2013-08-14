# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.hostname = "vagabond-lxc-host"
  config.vm.box = 'precise-64-lxc-preseed'
  config.vm.box_url = 'http://vagrant.hw-ops.com/precise-64-lxc-preseed.box'

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
        "apt-get install -y -q ruby1.9.1-full git",
        "gem install --no-ri --no-rdoc bundler",
        "gem install --no-ri --no-rdoc vagabond"
      ]
    ).join("\n")
  end

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--cpus", "2"]
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end
end
