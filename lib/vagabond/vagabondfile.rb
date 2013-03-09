require 'chef/mash'

module Vagabond
  class Vagabondfile

    attr_reader :path
    attr_reader :config

    def initialize(path=nil)
      path = discover_path(Dir.pwd) unless path
      @path = path
      load_configuration!
    end

    def [](k)
      @config[k]
    end

    def load_configuration!
      raise 'No Vagabondfile file found!' unless @path && File.exists?(@path)
      @config = Mash.new(self.instance_eval(IO.read(@path), @path, 1))
    end

    def discover_path(path)
      d_path = Dir.glob(File.join(path, 'Vagabondfile')).first
      unless(d_path)
        cut_path = path.split(File::SEPARATOR)
        cut_path.pop
        d_path = discover_path(cut_path.join(File::SEPARATOR)) unless cut_path.empty?
      end
      d_path
    end
  end
end
