module Vagabond
  module Nests

    module Methods

      def retreive(collection, *args)
        unless(collection.is_a?(Hash))
          raise TypeError.new("Expecting Hash collection. Got #{collection.class}")
        end
        args.inject(collection) do |memo, key|
          memo[key.to_s] || memo[key.to_sym] || break
        end
      end

    end

    class << self
      def included(klass)
        klass.include(Methods)
      end
      include Methods
    end

  end
end
