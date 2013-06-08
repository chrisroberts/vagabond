require 'vagabond/uploader'

module Vagabond
  class Uploader
    class Knife < Uploader

      def upload(*args)
        prepare unless args.include?(:no_prepare)
        com = "knife cookbook upload#{options[:knife_opts]} --all"
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
