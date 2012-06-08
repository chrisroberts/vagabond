def initialize(*args)
  super
  @action = :create
end

actions :create, :delete

attribute :config, :kind_of => Hash, :default => {}
