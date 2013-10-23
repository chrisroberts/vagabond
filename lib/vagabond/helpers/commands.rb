#encoding: utf-8

require 'vagabond/constants'

module Vagabond
  module Helpers
    module Commands

      def direct_container_command(command, args={})
        _lxc = args[:lxc] || lxc
        com = "#{sudo}ssh root@#{lxc.container_ip} -i #{Settings[:ssh_key]} -oStrictHostKeyChecking=no '#{command}'"
        debug(com)
        begin
          cmd = Mixlib::ShellOut.new(com,
            :live_stream => args[:live_stream] || options[:debug],
            :timeout => args[:timeout] || 1200
          )
          cmd.run_command
          cmd.error!
          cmd
        rescue
          raise if args[:raise_on_failure]
          false
        end
      end

      def via_bundle
        if(defined?(Bundler) && Bundler.bundle_path)
          'bundle exec '
        end
      end

      def build_command(command, args={})
        command = "#{via_bundle}#{command}" unless args[:no_bundle]
        command = "#{sudo}#{command}" if args[:sudo]
        pre_args = args[:shellout] || {}
        debug(command)
        cmd = Mixlib::ShellOut.new(
          command, {
            :live_stream => options[:debug],
            :timeout => 3600
          }.merge(pre_args)
        )
        cmd
      end

    end
  end
end
