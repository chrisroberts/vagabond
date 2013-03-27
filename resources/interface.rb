actions :create, :delete
default_action :create

attribute :container, :kind_of => String, :required => true
attribute :device, :kind_of => String, :required => true
attribute :auto, :kind_of => [TrueClass, FalseClass], :default => true
attribute :dynamic, :kind_of => [TrueClass, FalseClass], :default => false
attribute :address, :regex => %r{\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}}
attribute :gateway, :regex => %r{\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}}
attribute :netmask, :regex => %r{\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}}, :default => '255.255.255.0'
attribute :ipv6, :kind_of => [TrueClass,FalseClass], :default => false
