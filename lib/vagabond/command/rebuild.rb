#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Rebuild a node
    class Rebuild < Command

      # Destroy and rebuild node
      def run!
        arguments.each do |name|
          Destroy.new(options.merge(:ui => ui), [name]).execute!
          Up.new(options.merge(:ui => ui), [name]).execute!
        end
      end
    end

  end
end
