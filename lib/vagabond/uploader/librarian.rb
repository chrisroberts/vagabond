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
        File.open(File.join(store, 'Cheffile'), 'w') do |file|
          file.puts File.read(options[:cheffile])
          file.puts "cookbook 'minitest-handler'"
        end
        com = "librarian-chef update"
        debug(com)
        cmd = Mixlib::ShellOut.new(com,
          :live_stream => options[:debug],
          :cwd => store
        )
        cmd.run_command
        cmd.error!
      end
      
    end
  end
end
