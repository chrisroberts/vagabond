#encoding: utf-8
Dir.new(File.join(File.dirname(__FILE__), 'uploader')).each do |file|
  next if file.start_with?('.') || !file.end_with?('.rb')
  require "vagabond/uploader/#{file}"
end

require 'vagabond/helpers'

module Vagabond
  class Uploader

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
