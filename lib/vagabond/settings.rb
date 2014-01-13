require 'vagabond'

module Vagabond
  class Settings
    class << self
      def [](k)
        @v ||= Mash.new
        @v[k]
      end
      def []=(k,v)
        @v ||= Mash.new
        @v[k] = v
        v
      end
    end
  end
end
