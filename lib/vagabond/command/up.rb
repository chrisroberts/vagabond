#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Create and provision
    class Up < Command

      # Create and provision node(s)
      def run!
        # Creation is serial so do all creates up front
        Create.new(options.merge(:ui => ui), arguments).execute!
        arguments.map do |name|
          thread = Thread.new do
            Provision.new(options.merge(:ui => ui), [name]).execute!
          end
          unless(options[:parallel])
            thread.join
          end
          thread
        end.map(&:join)
      end

    end
  end
end
