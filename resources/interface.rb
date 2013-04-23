actions :create, :delete
default_action :create

attribute :container, :kind_of => String, :required => true
attribute :device, :kind_of => String, :required => true
attribute :auto, :kind_of => [TrueClass, FalseClass], :default => true
attribute :dynamic, :kind_of => [TrueClass, FalseClass], :default => false
attribute :address, :kind_of => String
attribute :gateway, :kind_of => String
attribute :up, :kind_of => String
attribute :down, :kind_of => String
attribute :netmask, :kind_of => [String,Numeric]
attribute :ipv6, :kind_of => [TrueClass,FalseClass], :default => false
