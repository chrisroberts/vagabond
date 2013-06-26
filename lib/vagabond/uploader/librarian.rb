require 'vagabond/uploader/knife'

module Vagabond
  class Uploader
    class Librarian < Knife

      def initialize(*args)
        super
        unless(options[:cheffile])
          raise ArgumentError.new "Option 'cheffile' is required!"
        end
        unless(File.exists?(options[:cheffile]))
          raise ArgumentError.new "Option 'cheffile' is not a valid path!"
        end
      end

      def prepare
        if(File.directory?(File.join(store, 'cookbooks')))
          com = 'librarian-chef update' # TODO: Check path in .librarian config
        else
          com = "librarian-chef install --path=#{File.join(store, 'cookbooks')}"
        end
        debug(com)
        cmd = Mixlib::ShellOut.new(com,
          :live_stream => options[:debug],
          :cwd => File.dirname(options[:cheffile])
        )
        cmd.run_command
        cmd.error!
        options[:cookbook_paths] = [File.join(store, 'cookbooks')]
      end
      
    end
  end
end
