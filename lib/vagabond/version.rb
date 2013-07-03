#encoding: utf-8
module Vagabond
  class Version < Gem::Version
    attr_reader :codename
    def initialize(v, name)
      @codename = name
      super(v)
    end
  end
  VERSION = Version.new('0.2.9', 'Hey, want to hear the most annoying sound in the world?')
end
