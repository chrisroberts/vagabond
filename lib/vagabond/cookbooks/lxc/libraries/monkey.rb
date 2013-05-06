unless(defined?(LxcMonkey))
  require 'chef/resource/execute'
  require 'chef/provider/execute'

  module LxcMonkey
    module Provider
      class << self
        def included(klass)
          klass.class_eval do
            alias_method :non_monkey_shell_out!, :shell_out!
            alias_method :shell_out!, :monkey_shell_out!
          end
        end
      end
      
      def monkey_shell_out!(com, opts)
        if(str = @new_resource.stream_output)
          opts[:live_stream] = str.kind_of?(IO) ? str : STDOUT
        end
        non_monkey_shell_out!(com, opts)
      end      
    end
    module Resource

      class << self
        def included(klass)
          klass.class_eval do
            alias_method :non_monkey_initialize, :initialize
            alias_method :initialize, :monkey_initialize
          end
        end
      end
      
      def monkey_initialize(*args)
        non_monkey_initialize(*args)
        @stream_output = nil
      end

      def stream_output(arg=nil)
        set_or_return(
          :stream_output,
          arg,
          :kind_of => [TrueClass,FalseClass,IO]
        )
      end
    end
  end

  Chef::Resource::Execute.send(:include, LxcMonkey::Resource)
  Chef::Provider::Execute.send(:include, LxcMonkey::Provider)
end
