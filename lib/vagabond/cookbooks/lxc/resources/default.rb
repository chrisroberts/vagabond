actions :create, :delete, :clone
default_action :create

attribute :template, :kind_of => String, :default => 'ubuntu'
attribute :template_opts, :kind_of => Hash, :default => {}
attribute :base_container, :kind_of => String

# Backing store options. Not yet in use
attribute :fstype, :kind_of => String, :default => 'ext4'
attribute :fssize, :kind_of => String, :default => '2G'
attribute :vgname, :kind_of => String
attribute :lvname, :kind_of => String
