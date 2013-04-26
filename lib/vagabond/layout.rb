module Vagabond
  class Layout

    def initialize(base_dir)
      unless(File.exists?(path = File.join(base_dir, 'spec/Layout')))
        raise 'Spec layout file does not exist'
      end
      @l = Mash.new(self.instance_eval(IO.read(path), path, 1))
    end

    def [](k)
      @l[k]
    end

  end
end
