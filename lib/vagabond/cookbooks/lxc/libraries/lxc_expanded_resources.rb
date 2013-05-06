module ChefLxc
  module Resource

    def container(arg=nil)
      set_or_return(:container, arg, :kind_of => [String], :required => true)
    end

    def lxc
      @lxc ||= Lxc.new(
        @container,
        :base_dir => node[:lxc][:container_directory]
      )
    end

    def path(arg=nil)
      arg ? super(arg) : lxc.expand_path(super(arg))
    end

    def self.included(base)
      base.class_eval do
        def initialize(*args)
          super
          @container = nil
        end
      end
    end
  end
end

class Chef
  class Resource
    class LxcTemplate < Template
      include ChefLxc::Resource
    end

    class LxcFile < File
      include ChefLxc::Resource
    end
  end
end
