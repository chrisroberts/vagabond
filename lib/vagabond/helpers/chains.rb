#encoding: utf-8
require 'vagabond/constants'

module Vagabond
  module Helpers
    module Chains

      def add_link(action, name, opts={})
        @chain ||= []
        @chain << {:action => action, :name => name, :options => opts}
      end

      def chain!
        if(@chain)
          while(to_run = @chain.shift)
            run_action(to_run[:action], to_run[:name], to_run[:options])
          end
        end
      end

    end
  end
end
