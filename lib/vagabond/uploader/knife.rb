#encoding: utf-8
require 'vagabond/uploader'

module Vagabond
  class Uploader
    class Knife < Uploader

      def upload(*args)
        prepare unless args.include?(:no_prepare)
        com = "cookbook upload#{options[:knife_opts]} --all"
        if(options[:cookbook_paths])
          com << " --cookbook-path #{Array(options[:cookbook_paths]).join(':')}"
        end
        cmd = knife_command(com, :cwd => store)
        cmd.run_command
        cmd.error!
      end
      
    end
  end
end
