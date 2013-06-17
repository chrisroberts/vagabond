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
        com = "librarian-chef install --path=#{store}"
        debug(com)
        cmd = Mixlib::ShellOut.new(com,
          :live_stream => options[:debug],
          :cwd => File.dirname(options[:cheffile])
        )
        cmd.run_command
        cmd.error!
        options[:cookbook_paths] = [store]
      end
      
    end
  end
end
