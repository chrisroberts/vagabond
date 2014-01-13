#encoding: utf-8

require 'vagabond'

module Vagabond
  class Uploader

    autoload :Berkshelf, 'vagabond/uploaders/berkshelf'
    autoload :Knife, 'vagabond/uploaders/knife'
    autoload :Librarian, 'vagabond/uploaders/librarian'

    attr_reader :store
    attr_reader :options
    attr_reader :ui
    attr_reader :vagabondfile

    include Helpers

    def initialize(vagabondfile, base_directory, options={})
      @store = base_directory
      @options = Mash.new(options)
      @ui = options[:ui]
      @vagabondfile = vagabondfile
    end

    def prepare
    end

    def upload
    end

  end
end
