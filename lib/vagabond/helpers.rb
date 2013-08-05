#encoding: utf-8
require 'vagabond/constants'

Dir.glob(File.join(File.dirname(__FILE__), 'helpers/*.rb')).each do |path|
  require "vagabond/helpers/#{File.basename(path).sub('.rb', '')}"
end

module Vagabond
  module Helpers
    class << self
      
      def included(klass)
        ::Vagabond::Helpers.constants.each do |konst|
          const = ::Vagabond::Helpers.const_get(konst)
          next unless const.is_a?(Module)
          klass.send(:include, const)
        end
      end
      
    end
  end
end
