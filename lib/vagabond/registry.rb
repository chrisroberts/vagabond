require 'vagabond'

module Vagabond
  # Information registry
  class Registry < Bogo::Config

    # Represents metadata for single entry of vagabond usage (tied to
    # a specific directory on the system)
    class Entry < Bogo::Config
      attribute :nodes, Smash, :default => Smash.new
      attribute :test_nodes, Smash, :default => Smash.new
      attribute :clusters, Smash, :default => Smash.new
      attribute :test_clusters, Smash, :default => Smash.new
      attribute :templates, Smash, :default => Smash.new
      attribute :dev_mode, Integer, :default => Time.now.to_i
      attribute :version, String, :default => Vagabond::VERSION.version
    end

    attribute :entries, Smash, :default => Smash.new, :coerce => lambda{|v| Smash[v.map{|k,v| [k, Entry.new(v)]}]}

    # Save the registry to disk
    #
    # @return [TrueClass]
    def save!
      file = File.open(path, File::RDWR|File::CREAT, 0644)
      file.flock(File::LOCK_EX)
      file.rewind
      file.write MultiJson.dump(data)
      file.truncate(file.pos)
      file.close
      true
    end

  end
end
