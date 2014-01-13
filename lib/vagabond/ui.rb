
require 'vagabond'
require 'stringio'
require 'chef/knife/core/ui'

module Vagabond
  class Ui < Chef::Knife::Ui

    class << self
      def ui(ui=nil)
        unless(@ui)
          @ui = ui
        end
        @ui
      end
    end

    # Returns end point for debug output
    def debug_stream
      @stdout
    end
    alias_method :live_stream, :debug_stream

    # Simple wrapper to knife ui for cli based usage
    class Cli < Ui
    end

    # Wrapper for knife ui to capture output and provide nicely
    # hashified return value { Hashes }
    class Daemon < Ui

      attr_reader :stdout, :stderr

      def initialize(s_out, s_err, s_in, config)
        @stdout = StringIO.new
        @stderr = StringIO.new
        super(stdout, stderr, s_in, config)
      end

      # Returns currently cached output in stdout and stderr streams
      # in hash with array values. Truncates streams after read.
      def output
        stdout.rewind
        stderr.rewind
        result = {
          :stdout => stdout.read.split("\n"),
          :stderr => stderr.read.split("\n")
        }
        stdout.truncate(stdout.pos)
        stderr.truncate(stderr.pos)
        result
      end

    end

  end
end
