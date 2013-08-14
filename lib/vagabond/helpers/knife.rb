#encoding: utf-8

require 'vagabond/settings'
require 'vagabond/constants'
require 'vagabond/helpers/commands'

module Vagabond
  module Helpers
    module Knife

      def knife_command(action, opts={})
        conf = knife_config_build.to_a.map do |ary|
          scrub = ary.compact.map do |arg|
            if(arg)
              arg.gsub('_', '-')
            end
          end
          "--#{scrub.join(' ')}"
        end.join(' ')
        build_command("knife #{action} #{conf}", :shellout => opts)
      end

      def knife_config_build
        base = Mash.new
        if(File.exists?(kconf = File.join(vagabondfile.store_directory, '.chef/knife.rb')))
          base[:config] = File.expand_path(kconf)
        end
        base.merge(knife_config)
      end
      
      def knife_config(args = {})
        Settings[:knife] ||= Mash.new
        Settings[:knife].merge!(args)
        Settings[:knife]
      end

      class << self
        def included(klass)
          unless(klass.ancestors.include?(::Vagabond::Helpers::Commands))
            klass.send(:include, ::Vagabond::Helpers::Commands)
          end
        end
      end
      
    end
  end
end
