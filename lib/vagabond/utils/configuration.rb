require 'vagabond'

module Vagabond
  module Utils
    module Configuration

      # @return [Registry] system registry
      def registry
        memoize(:registry) do
          registry_path = File.join(vagabondfile.global_cache, 'registry.json')
          unless(File.exists?(registry_path))
            File.open(registry_path, 'w'){|f| f.puts '{}'}
          end
          Registry.new(registry_path)
        end
      end

      # @return [Smash] local registry
      def local_registry
        memoize(:local_registry) do
          unless(registry.entries.get(vagabondfile.fid))
            registry.entries.set(vagabondfile.fid, Smash.new)
          end
          registry.entries[vagabondfile.fid]
        end
      end

    end
  end
end
