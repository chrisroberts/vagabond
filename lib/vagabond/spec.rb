require 'thor'
require File.join(File.dirname(__FILE__), 'cookbooks/lxc/libraries/lxc.rb')

%w(layout vagabond server helpers vagabondfile internal_configuration actions/status).each do |dep|
  require "vagabond/#{dep}"
end

module Vagabond
  class Spec < Thor

    include Thor::Actions
    include Helpers
    include Actions::Status

    attr_accessor :layout

    self.class_exec(&Vagabond::CLI_OPTIONS)

    def self.basename
      'vagabond spec'
    end
    
    def initialize(*args)
      @name = nil
      super
    end

    method_option(:irl,
      :type => :boolean,
      :default => false,
      :desc => 'Test In Real Life'
    )
    method_option(:environment,
      :type => :string,
      :desc => 'Specify environment to restrict node detection'
    )
    desc 'start [CLUSTER]', 'Run specs for cluster'
    def start(cluster=nil)
      @options = options.dup
      setup_ui(nil, :no_class_set)
      if(options[:irl])
        irl_spec(cluster)
      else
        cluster_spec(cluster)
      end
    end

    desc 'status [NAME]', 'Show status of existing nodes'
    def status(name=nil)
      base_setup
      _status
    end
    
    protected

    def mappings_key
      :spec_mappings
    end
    
    def irl_spec(cluster)
      if(cluster && load_layout[cluster])
        valid_runlists = layout[:clusters][cluster][:nodes]
        # Runlists composed of role AND/OR recipe
        valid_runlists.each do |r_l|
          runlist = r_l.map{|r| Chef::RunList::RunListItem.new(r)}
          roles = runlist.find_all do |i|
            i.role?
          end
          recipes = runlist.find_all do |i|
            i.recipe?
          end
          terms = roles.map{|r| "role:#{r.name}"} + recipes.map{|r| "recipes:#{r.name}"}
          query = terms.join(' AND ')
          if(options[:environment])
            query = "chef_environment:#{options[:environment]} AND (#{query})"
          end
          search(:node, query).each do |node|
            n_r = node.run_list.map(&:to_s)
            next unless n_r.size == r_l.size && (n_r - r_l).empty?
            test_node!(node.name, node.ipaddress, node.run_list)
          end
        end
      else
        query = %w(*:*)
        if(options[:environment])
          query << "chef_environment:#{options[:environment]}"
        end
        Chef::Search::Query.new(:node, query.join(' AND ')) do |nodes|
          nodes.each do |node|
            test_node!(node.name, node.ipaddress, node.run_list)
          end
        end
      end
    end

    def cluster_spec(cluster)
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

      load_layout
      default_config = Chef::Mixin::DeepMerge.merge(
        Mash.new(:platform => 'ubuntu_1204'), layout[:defaults]
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
        name, lxc_name, config = node
        lxc = Lxc.new(lxc_name)
        test_node!(name, lxc.container_ip, config[:run_list])
      end
    end
    
    def test_node!(name, ip_address, run_list)
      run_list.each do |item|
        r_item = item.is_a?(Chef::RunList::RunListItem) ? item : Chef::RunList::RunListItem.new(item)
        dir = File.join(File.dirname(@vagabondfile.path), "spec/#{r_item.type}/#{r_item.name.sub('::', '_')}")
        Dir.glob(File.join(dir, '*.rb')).each do |path|
          com = "#{sudo}VAGABOND_TEST_HOST='#{ip_address}' rspec #{path}"
          debug(com)
          cmd = Mixlib::ShellOut.new(com, :live_stream => STDOUT, :env => {'VAGABOND_TEST_HOST' => ip_address})
          cmd.run_command
          cmd.error!
        end
      end
    end

    def load_layout
      # Load up layouts and set defaults
      @layout = Layout.new(File.dirname(@vagabondfile.path))
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

  
