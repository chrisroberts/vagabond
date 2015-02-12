#encoding: utf-8
module Vagabond
  class Error < StandardError

    class << self
      # @return [Integer] exit code
      attr_accessor :exit_code

      def inherited(klass)
        @@errors ||= []
        @@errors << klass
        klass.exit_code = @@errors.index(klass) + 1
      end
    end

    # @return [Integer] exit code
    def exit_code
      self.class.exit_code
    end

    class ReservedName < Error; end
    class InvalidName < Error; end
    class InvalidBaseTemplate < Error; end
    class InvalidAction < Error; end
    class InvalidTemplate < Error; end
    class KitchenMissingYml < Error; end
    class KitchenNoCookbookArgs < Error; end
    class KitchenTooManyArgs < Error; end
    class KitchenInvalidPlatform < Error; end
    class MissingNodeName < Error; end
    class ClusterInvalid < Error; end
    class KitchenTestFailed < Error; end
    class HostProvisionFailed < Error; end
    class SpecFailed < Error; end
    class NodeProvisionFailed < Error; end
    class LibrarianHostInstallFailed < Error; end
    class ErchefBaseMissing < Error; end
    class NodeNotRunning < Error; end
    class NodeNotCreated < Error; end
    class InvalidRequest < Error; end
    class CommandFailed < Error; end
    class NodeNotFrozen < Error; end
    class NotImplemented < Error; end
    class ProcessLocked < Error; end
    class ServerDisabled < Error; end
    class UnknownResolver < Error; end

  end
end
