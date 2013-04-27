require 'thor'
require File.join(File.dirname(__FILE__), 'cookbooks/lxc/libraries/lxc.rb')

%w(layout vagabond server helpers vagabondfile internal_configuration).each do |dep|
  require "vagabond/#{dep}"
end

module Vagabond
  class Spec < Thor

    include Thor::Actions
    include Helpers

    attr_accessor :ui
    attr_accessor :layout
    
    self.class_exec(&Vagabond::CLI_OPTIONS)
    
    def initialize(*args)
      super
    end
    
    desc 'spec CLUSTER', 'Run specs for cluster'
    def spec(cluster)
      @options = options.dup
      setup_ui(nil, :no_class_set)
      @options[:auto_provision] = true
      @vagabondfile = Vagabondfile.new(options[:vagabond_file])
      options[:sudo] = sudo
      Lxc.use_sudo = @vagabondfile[:sudo].nil? ? true : @vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(@vagabondfile, nil, options)
      # First, setup server
      if(@vagabondfile[:local_chef_server][:enabled])
        require 'vagabond/server'
        srv = ::Vagabond::Server.new
        srv.send(:setup, 'up')
        srv.send(:execute)
      end

      # Load up layouts and set defaults
      @layout = Layout.new(File.dirname(@vagabondfile.path))
      default_config = Chef::Mixin::DeepMerge.merge(
        Mash.new(:platform => 'ubuntu_1204', :union => 'aufs'), layout[:defaults]
      )
      test_nodes = layout[:clusters][cluster][:nodes].map do |node|
        config = Chef::Mixin::DeepMerge.merge(default_config, layout[:definitions][node])
        config = Chef::Mixin::DeepMerge.merge(config, layout[:clusters][cluster][:overrides] || {})
        v_n = vagabond_instance(:up, config[:platform], :base_name => node)
        v_n.config = Chef::Mixin::DeepMerge.merge(v_n.config, config)
        v_n.send(:execute)
        [v_n.name, v_n.lxc.name, config]
      end
      test_nodes.each do |node|
        test_node!(*node)
      end
    end

    protected
    
    def test_node!(name, lxc_name, config)
      lxc = Lxc.new(lxc_name)
      config[:run_list].each do |item|
        r_item = Chef::RunList::RunListItem.new(item)
        if(r_item.role?)
          dir = File.join(File.dirname(@vagabondfile.path), "spec/#{r_item.name}")
          Dir.glob(File.join(dir, '*.rb')).each do |path|
            com = "#{sudo}LXC_TEST_HOST='#{lxc.container_ip}' rspec #{path}"
            debug(com)
            cmd = Mixlib::ShellOut.new(com, :live_stream => STDOUT, :env => {'LXC_TEST_HOST' => lxc.container_ip})
            cmd.run_command
            cmd.error!
          end
        end
      end
    end
    
    def vagabond_instance(action, platform, args={})
      @options[:disable_name_validate] = true
      v = Vagabond.new
      v.options = @options
      v.send(:setup, action, random_name(args[:base_name]),
        :ui => ui,
        :template => platform,
        :disable_name_validate => true,
        :ui => ui
      )
      v.internal_config.force_bases = platform
      v.internal_config.ensure_state
      v.mappings_key = :spec_mappings
      v.config = Mash.new(
        :template => platform,
        :run_list => args[:run_list]
      )
      v.lxc = Lxc.new(
        v.internal_config[v.mappings_key][v.name]
      ) if v.internal_config[v.mappings_key][v.name]
      v
    end
    
  end
end

  
