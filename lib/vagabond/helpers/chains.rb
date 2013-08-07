#encoding: utf-8
require 'vagabond/constants'

module Vagabond
  module Helpers
    module Chains

      def add_link(action)
        @chain ||= []
        @chain << action
      end

      def chain!
        if(@chain)
          while(action = @chain.shift)
            send(action, *@original_args)
          end
        end
      end

    end
  end
end
