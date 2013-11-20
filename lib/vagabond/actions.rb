Dir.glob(File.join(File.dirname(__FILE__), 'actions', '*.rb')).each do |file|
  lib = File.basename(file).sub('.rb', '')
  require "vagabond/actions/#{lib}"
end

module Vagabond
  module Actions
    class << self

      # Array of registered modules
      def modules
        @mods ||= []
      end

      # mod:: Module
      # Register module
      def register(mod)
        modules.push(mod).uniq!
      end

    end
  end
end
