#encoding: utf-8
require 'thor'
require 'elecksee/lxc'

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
    method_option(:auto_destroy,
      :type => :boolean,
      :desc => 'Automatically destroy created nodes after spec tests (not valid with --irl)',
      :default => true
    )
    desc 'start [CLUSTER]', 'Run specs for cluster'
    def start(cluster=nil)
      @options = options.dup
      setup_ui(nil, :no_class_set)
      error = nil
      begin
        if(options[:irl])
          irl_spec(cluster)
        else
          cluster_spec(cluster)
          cluster_destroy(cluster) if options[:auto_destroy]
        end
      rescue => error
        ui.error "Unexpected error encountered: #{error}"
        debug("#{error.class}: #{error}\n#{error.backtrace.join("\n")}")
        raise
      ensure
        result = error ? ui.color('FAILED', :red, :bold) : ui.color('PASSED', :green, :bold)
        ui.info "--> Specs for cluster #{cluster}: #{result}"
        raise VagabondError::SpecFailed.new(error) if error
      end
    end
    
    method_option(:node,
      :type => :string,
      :desc => 'Destroy named node within cluster cluster'
    )
    desc 'destroy NAME', 'Destroy the given cluster/node'
    def destroy(cluster)
      base_setup
      options[:node] ? node_destroy(cluster, options[:node]) : cluster_destroy(cluster)
    end

    desc 'status [NAME]', 'Show status of existing nodes'
    def status(name=nil)
      base_setup
      _status
    end

    desc 'init', 'Initalize spec configuration'
    def init
      setup_ui(nil, :no_class_set)
      ui.info "Initializing spec configuration..."
      make_spec_directory
      populate_spec_directory
      # - dump empty layout
      ui.info "  -> #{ui.color('COMPLETE!', :green)}"
    end
    
    protected

    def cluster_destroy(cluster)
      ui.info "#{ui.color('Destroying cluster:', :bold)} #{ui.color(cluster, :red)}"
      Array(internal_config[:spec_clusters][cluster]).each do |n|
        node_destroy(cluster, n)
      end
      ui.info ui.color(" --> Cluster #{cluster} DESTROYED", :red)
    end

    def node_destroy(cluster, node_name)
      v_n = vagabond_instance(:destroy, :cluster => cluster, :name => node_name)
      v_n.send(:execute)
      remove_node_from_cluster(cluster, node_name)
    end
    
    def make_spec_directory
      %w(role recipe).each do |leaf|
        FileUtils.mkdir_p(File.join(spec_directory, leaf))
      end
    end

    def spec_directory
      File.join(vagabondfile.directory, 'spec')
    end

    def populate_spec_directory
      write_default_file('Layout')
      write_default_file('spec_helper.rb')
    end

    def write_default_file(file)
      write = true
      if(File.exists?(path = File.join(spec_directory, file)))
        answer = ''
        until(%w(y n).include?(answer))
          answer = ui.ask_question("Overwrite existing #{file} ", :default => 'y').downcase
        end
        write = answer == 'y'
      end
      if(write)
        File.open(path, 'w') do |file|
          file.write self.class.const_get("CONTENT_DEFAULT_#{File.basename(path).upcase.sub(%r{\..*$}, '')}")
        end
        ui.info "New file has been written: #{file}"
      else
        ui.warn "Skipping file: #{file}"
      end
    end
    
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

    def vagabondfile
      unless(@vagabondfile)
        @vagabondfile = Vagabondfile.new(options[:vagabond_file], :allow_missing)
      end
      @vagabondfile
    end
    
    def cluster_spec(cluster)
      @options[:auto_provision] = true
      options[:sudo] = sudo
      Lxc.use_sudo = vagabondfile[:sudo].nil? ? true : vagabondfile[:sudo]
      @internal_config = InternalConfiguration.new(vagabondfile, ui, options)
      
      load_layout

      setup_server_if_needed

      default_config = Chef::Mixin::DeepMerge.merge(
        Mash.new(:platform => 'ubuntu_1204'), layout[:defaults]
      )
      test_nodes = []
      layout[:clusters][cluster][:nodes].each_with_index do |node, index|
        config = Chef::Mixin::DeepMerge.merge(default_config, layout[:definitions][node])
        config = Chef::Mixin::DeepMerge.merge(config, layout[:clusters][cluster][:overrides] || {})
        v_n = vagabond_instance(:up,
          :platform => config[:platform],
          :cluster => cluster,
          :base_name => "s-#{node}-#{index}"
        )
        v_n.config = Chef::Mixin::DeepMerge.merge(v_n.config, config)
        v_n.send(:execute)
        test_nodes << [v_n.name, v_n.lxc.name, config]
      end
      test_nodes.each do |node|
        name, lxc_name, config = node
        lxc = Lxc.new(lxc_name)
        test_node!(name, lxc.container_ip, config)
      end

      destroy_server_if_needed
    end
    
    def test_node!(name, ip_address, node_config)
      test_files = []
      Array(node_config[:run_list]).each do |item|
        r_item = item.is_a?(Chef::RunList::RunListItem) ? item : Chef::RunList::RunListItem.new(item)
        dir = File.join(File.dirname(vagabondfile.path), "spec/#{r_item.type}/#{r_item.name.sub('::', '/')}")
        dir << '/default' if r_item.type.to_sym == :recipe && !r_item.name.include?('::')
        test_files += Dir.glob(File.join(dir, '*.rb')).map(&:to_s)
      end
      Array(node_config[:custom_specs]).each do |custom|
        dir = File.join(vagabondfile.directory, 'spec/custom', File.join(*custom.split('::')))
        test_files += Dir.glob(File.join(dir, '*.rb')).map(&:to_s)
      end
      test_files.flatten.compact.each do |path|
        ui.info "\n#{ui.color('**', :green, :bold)}  Running spec: #{path.sub("#{vagabondfile.directory}/", '')}"
        cmd = build_command("VAGABOND_TEST_HOST='#{ip_address}' rspec #{path}", :live_stream => STDOUT, :env => {'VAGABOND_TEST_HOST' => ip_address})
        cmd.run_command
        cmd.error!
      end
    end

    def load_layout
      # Load up layouts and set defaults
      @layout = Layout.new(File.dirname(vagabondfile.path))
    end
    
    def vagabond_instance(action, args={})
      @options[:disable_name_validate] = true
      v = Vagabond.new
      v.options = @options
      v.send(:setup, action, args[:name] || generated_name(args[:base_name]),
        :ui => ui,
        :template => args[:platform],
        :disable_name_validate => true,
        :ui => ui
      )
      if(args[:platform])
        v.internal_config.force_bases = args[:platform]
        v.internal_config.ensure_state
      end
      v.mappings_key = :spec_mappings
      v.config = Mash.new(
        :template => args[:platform],
        :run_list => args[:run_list]
      )
      v.lxc = Lxc.new(
        v.internal_config[v.mappings_key][v.name]
      ) if v.internal_config[v.mappings_key][v.name]
      add_node_to_cluster(v.name, args[:cluster])
      v
    end

    def _status
      status = []
      if(name)
        clusters = [name]
      else
        load_layout
        clusters = layout[:clusters].keys.sort
      end
      clusters.each do |cluster|
        ui.info "#{ui.color('Status of spec cluster:', :bold)} #{ui.color(cluster, :yellow)}"
        status = [
          ui.color('Name', :bold),
          ui.color('State', :bold),
          ui.color('PID', :bold),
          ui.color('IP', :bold)
        ]
        Array(internal_config[:spec_clusters][cluster]).sort.each do |n|
          status += status_for(n)
        end
        puts ui.list(status, :uneven_columns_across, 4)
      end
    end

    def add_node_to_cluster(node_name, cluster)
      internal_config[:spec_clusters][cluster] ||= []
      internal_config[:spec_clusters][cluster] |= [node_name]
      internal_config.save
    end

    def remove_node_from_cluster(cluster, node_name)
      internal_config[:spec_clusters][cluster] ||= []
      internal_config[:spec_clusters][cluster] -= [node_name]
      internal_config[mappings_key].delete(node_name)
      internal_config.save
    end
    
    CONTENT_DEFAULT_LAYOUT = <<-EOF
{
  :defaults => {
    :platform => 'ubuntu_1204',
    :environment => nil
  },
  :definitions => {
    :example_node => {
      :run_list => %w(role[example])
    }
  },
  :clusters => {
    :example_cluster => {
      :nodes => ['example_node']
    }
  }
}
EOF
    CONTENT_DEFAULT_SPEC_HELPER = <<-EOF
require 'serverspec'
require 'pathname'
require 'net/ssh'

include Serverspec::Helper::Ssh

RSpec.configure do |c|
  c.before do
    host = ENV['VAGABOND_TEST_HOST']
    if(c.host != host)
      c.ssh.close if c.ssh
      c.host = host
      options = Net::SSH::Config.for(c.host)
      c.ssh = Net::SSH.start(c.host, 'root', options.update(:keys => ['/opt/hw-lxc-config/id_rsa']))
    end
  end
end
EOF
    
  end
end

  
