require 'vagabond/uploader/berkshelf'

module Vagabond
  class Uploader
    class Berkshelf < Uploader

      def initialize(*args)
        super
        %w(berksfile).each do |k|
          unless(options[k])
            raise ArgumentError.new "Option '#{k}' must be provided!"
          end
        end
      end

      def prepare
        path = File.join(store, 'berks.json')
        if(File.exists?(path))
          cur = Mash.new(JSON.load(File.read(path)))
        else
          cur = Mash.new
        end
        url = options[:chef_server_url] || 'http://127.0.0.1'
        if(cur[:chef].nil? || cur[:chef][:chef_server_url] != url)
          cur[:chef] = Mash.new(:chef_server_url => url)
          cur[:ssl] = Mash.new(:verify => false)
          File.open(path, 'w') do |file|
            file.write(JSON.dump(cur))
          end
        end
        vendor
        options[:cookbook_paths] = [File.join(store, 'cookbooks')]
      end

      def vendor(*args)
        FileUtils.mkdir_p(ckbk_store = File.join(store, 'cookbooks'))
        com = "berks install -b #{options[:berksfile]} -p #{ckbk_store}"
        debug(com)
        cmd = Mixlib::ShellOut.new(com, :live_stream => options[:debug])
        cmd.run_command
        cmd.error!
      end
    end
  end
end
