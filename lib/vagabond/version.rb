module Vagabond
  class Version < Gem::Version
    attr_reader :codename
    def initialize(v, name)
      @codename = name
      super(v)
    end
  end
  VERSION = Version.new('0.2.6', 'gutterpup')
end
