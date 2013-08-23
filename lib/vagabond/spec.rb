#encoding: utf-8
require 'thor'
require 'elecksee/lxc'

%w(vagabond server helpers vagabondfile internal_configuration actions/status).each do |dep|
  require "vagabond/#{dep}"
end

module Vagabond
  class Spec < Thor

    include Thor::Actions
    include Helpers
    include Actions::Status

    self.class_exec(&Vagabond::CLI_OPTIONS)

    def self.basename
      'vagabond spec'
    end
    
    def initialize(*args)
      @name = nil
      super
      base_setup(:no_configure, :no_validate)
    end

    method_option(:irl,
      :type => :boolean,
      :default => false,
      :desc => 'Test In Real Life'
    )
    method_option(:irl_connect,
      :type => :string,
      :default => 'ipaddress',
      :desc => 'Attribute to use for ssh connection'
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
      options[:node] ? node_destroy(cluster, options[:node]) : cluster_destroy(cluster)
    end

    desc 'status [NAME]', 'Show status of existing nodes'
    def status(name=nil)
      _status
    end

    desc 'init', 'Initalize spec configuration'
    def init
      ui.info "Initializing spec configuration..."
      make_spec_directory
      populate_spec_directory
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
      # TODO: Clean up this inject and spit error when nil returned
      address = options[:irl_connect].split('.').inject(node){|k,m| m[k] || {}}
      if(cluster && vagabondfile[:clusters][cluster])
        nodes = vagabondfile[:clusters][cluster].map do |item_name|
          vagabondfile.for_node(item_name, :allow_missing_node)
        end
        valid_runlists = nodes.map do |node|
          node[:run_list].map do |runlist_item|
            i = Chef::RunList::RunListItem.new(runlist_item)
            [i, "#{i.role? ? 'roles' : 'recipes'}:#{i.name}"]
          end
        end
        valid_runlists.each do |rl|
          query = rl.map(&:last)
          query.push("chef_environment:#{options[:environment]}") if options[:environment]
          search(:node, query.join(' AND ')).each do |node|
            node_runlist = node.run_list.map(&:to_s)
            next unless node_runlist.size == rl.size && (node_runlist - rl.map(&:first)).empty?
            test_node!(node.name, address, node.run_list)
          end
        end
      else
        query = %w(*:*)
        if(options[:environment])
          query << "chef_environment:#{options[:environment]}"
        end
        Chef::Search::Query.new(:node, query.join(' AND ')) do |nodes|
          nodes.each do |node|
            test_node!(node.name, address, node.run_list)
          end
        end
      end
    end

    def get_cluster(name)
      clusters = vagabondfile[:specs][:clusters] || Mash.new
      cluster = clusters[name] || Mash.new
      cluster[:nodes] = (vagabondfile[:clusters][name] || []) + (cluster[:nodes] || [])
      cluster
    end
    
    def cluster_spec(cluster)
      cluster = get_cluster(cluster)
      
      setup_server_if_needed

      index = 0
      test_nodes = cluster[:nodes].map do |node_name|
        config = vagabondfile.for_node(node_name, :allow_missing)
        config = vagabondfile.for_definition(node_name) unless config
        if(cluster[:overrides])
          config = Chef::Mixin::DeepMerge.merge(config, cluster[:overrides])
        end
        v_n = vagabond_instance(:create,
          :platform => config[:platform],
          :cluster => cluster,
          :base_name => "s-#{node_name}-#{index}"
        )
        v_n.config = Chef::Mixin::DeepMerge.merge(v_n.config, config)
        v_n.send(:execute)
        index += 1
        [v_n, v_n.lxc.name, config]
      end
      run_specs = [cluster[:provision] || :every].flatten.compact.map(&:to_sym)
      after = cluster[:after] || Mash.new
      (cluster[:provision] || 1).to_i.times do |i|
        count = i + 1
        test_nodes.each do |node|
          node_inst, lxc_name, config = node
          node_inst._provision
          ## specs
          if(run_specs.include?(:every) || run_specs.include?("after_#{count}".to_sym))
            test_node!(node_inst.name, node_inst.lxc.container_ip, config)
          end
        end
        if(after[:every])
          process_after(after[:every], test_nodes.map(&:first), cluster)
        end
        if(after[count.to_s])
          process_after(after[count.to_s], test_nodes.map(&:first), cluster)
        end
      end

      destroy_server_if_needed
    end

    def process_after(after, nodes, cluster_config)
      if(after[:pause])
        ui.info ui.color("  Pause run... (#{after[:pause]} seconds)")
        sleep(after[:pause].to_f)
      end
      if(after[:run])
        run_coms = []
        if(after[:run].is_a?(String))
          run_coms << [after[:run], nodes]
        else
          if(after[:run][:on])
            after[:run][:on].each do |dest, com|
              on_nodes = dest.map do |n|
                nodes[cluster_config[:nodes].index(n)]
              end.compact
              run_coms << [com, on_nodes]
            end
            after[:run].delete(:on)
          end
          # NOTE: This is just for where `:on` key is missed or people
          # just want to be lazy
          after[:run].each_pair do |dest, com|
            on_nodes = dest.map do |n|
              nodes[cluster_config[:nodes].index(n)]
            end.compact
            run_coms << [com, on_nodes]
          end
        end
        run_coms.each do |com_pair|
          com_pair.last.each do |node_inst|
            node_inst.direct_container_command(com_pair.first, :live_stream => STDOUT)
          end
        end
      end
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
        cmd = build_command("rspec #{path}", :live_stream => STDOUT, :shellout => {:env => {'VAGABOND_TEST_HOST' => ip_address}})
        cmd.run_command
        cmd.error!
      end
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
        clusters = Mash.new
        clusters.merge!(vagabondfile[:clusters] || Mash.new)
        clusters.merge!(vagabondfile[:specs][:clusters] || Mash.new)
        clusters = clusters.keys.sort
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
