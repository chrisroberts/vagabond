require 'vagabond/uploader'

module Vagabond
  class Uploader
    class Knife < Uploader

      def upload(*args)
        prepare unless args.include?(:no_prepare)
        com = "knife cookbook upload#{options[:knife_opts]} --all"
        if(options[:cookbook_paths])
          com << " --cookbook-path #{Array(options[:cookbook_paths]).join(':')}"
        end
        if(File.exists?(knife_config = File.join(store, '.chef/knife.rb')))
          com << " --config #{knife_config}"
        end
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
