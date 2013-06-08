require 'thor'
require 'chef'
require 'kitchen'
require 'kitchen/busser'
require 'kitchen/loader/yaml'
require 'vagabond/monkey/kitchen_config'

%w(helpers vagabondfile vagabond server helpers/cheffile_loader actions/status).each do |dep|
  require "vagabond/#{dep}"
end

module Vagabond
  class Kitchen < Thor

    include Thor::Actions
    include Helpers
    include Actions::Status

    class << self
      def basename
        'vagabond kitchen'
      end
    end

    self.class_exec(&Vagabond::CLI_OPTIONS)

    attr_reader :kitchen
    attr_reader :platform_map
    attr_reader :vagabondfile
    attr_reader :ui
    attr_reader :name
    attr_reader :action
    attr_reader :internal_config

    def initialize(*args)
      super
    end

    desc 'teardown COOKBOOK', 'Destroy containers related to COOKBOOK test'
    method_option(:platform,
      :type => :string,
      :desc => 'Specify platform to destroy'
    )
    method_option(:suite,
      :type => :string,
      :desc => 'Specify suite to destroy'
    )
    def teardown(cookbook)
      ui.info "#{ui.color('Vagabond:', :bold)} - Kitchen teardown for cookbook #{ui.color(name, :red)}"
      plats = [platform || options[:platform] || platform_map.keys].flatten
      plats.each do |plat|
        validate_platform!(plat)
        ui.info ui.color("  -> Tearing down platform: #{plat}", :red)
        vagabond_instance(:destroy, plat).send(:execute)
        ui.info ui.color("  -> Teardown of platform: #{plat} - COMPLETE!", :red)
      end
    end

    desc 'test [COOKBOOK]', 'Run test kitchen on COOKBOOK'
    method_option(:platform,
      :type => :string,
      :desc => 'Specify platform to test'
    )
    method_option(:cluster,
      :type => :string,
      :desc => 'Specify cluster to test'
    )
    method_option(:teardown,
      :type => :boolean,
      :default => true,
      :desc => 'Teardown nodes automatically after testing'
    )
    method_option(:parallel,
      :type => :boolean,
      :default => false,
      :desc => 'Build test nodes in parallel [not enabled yet]'
    )
    method_option(:suites,
      :type => :string,
      :desc => 'Specify suites to test [suite1,suite2,...]'
    )
    def test(*args)
      cookbook = args.first
      setup(cookbook, :test)

      ui.info "#{ui.color('Vagabond:', :bold)} - Kitchen testing for cookbook #{ui.color(name, :cyan)}"
      results = Mash.new
      platforms = [options[:platform] || platform_map.keys].flatten
      if(cluster_name = options[:cluster])
        ui.info ui.color("  -> Cluster Testing #{cluster_name}!", :yellow)
        if(kitchen.clusters.empty? || kitchen.clusters[cluster_name].nil?)
          ui.fatal "Requested cluster is not defined: #{options[:cluster]}"
          exit EXIT_CODES[:cluster_invalid]
        end
        serv = Server.new
        if(@solo && serv.vagabondfile[:local_chef_server].empty?)
          serv.vagabondfile[:local_chef_server].update(:enabled => true, :zero => true)
        end
        serv.options = options
        serv.send(:do_create)
        serv.auto_upload # upload everything : make optional?
        suites = kitchen.clusters[options[:cluster]]
        platforms.each do |platform|
          %w(local_server_provision test destroy).each do |action|
            suites.each do |suite_name|
              res = self.send("#{action}_node", platform, suite_name)
              if(action == 'test')
                results[platform] ||=[]
                results[platform] << {
                  :suite_name => suite_name,
                  :result => res
                }
              end
            end
          end
        end
        serv.destroy
      else
        suites = options[:suites] ? options[:suites].split(',') : ['default']
        platforms.each do |platform|
          suites.each do |suite_name|
            provision_node(platform, suite_name)
            results[platform] ||= []
            results[platform] << {
              :suite_name => suite_name,
              :result => test_node(platform, suite_name)
            }
            destroy_node(platform, suite_name)
          end
        end
      end
      ui.info ui.color('Kitchen Test Results:', :bold)
      results.each do |platform, infos|
        ui.info "  Platform: #{ui.color(platform, :blue, :bold)}"
        infos.each do |res|
          ui.info "    Suite: #{res[:suite_name]} -> #{res[:result] ? ui.color('SUCCESS!', :green) : ui.color('FAILED!', :red)}"
        end
      end
      exit EXIT_CODES[:kitchen_test_failed] if infos.detect{|res| !res[:result]}
    end

    desc 'status [NAME]', 'Show test node status'
    def status(name=nil)
      setup(name, :status)
      _status
    end

    protected

    def mappings_key
      :test_mappings
    end

    def local_server_provision_node(platform, suite_name)
      run_list = generate_runlist(platform, suite_name)
      v_inst = vagabond_instance(:up, platform, :suite_name => suite_name, :run_list => run_list)
      raise "ERROR! No local chef!" unless v_inst.options[:knife_opts]
      v_inst.send(:execute)
    end

    # TODO: Handle failed provision!
    def provision_node(platform, suite_name)
      run_list = generate_runlist(platform, suite_name)
      ui.info ui.color("  -> Provisioning suite #{suite_name} on platform: #{platform}", :cyan)
      v_inst = vagabond_instance(:create, platform, :suite_name => suite_name)
      v_inst.send(:execute)
      solo_path = configure_for(v_inst.name, platform, suite_name, run_list, :dna, :cookbooks)
      v_inst.send(:provision_solo, solo_path)
    end

    def test_node(platform, suite_name)
      v_inst = vagabond_instance(:create, platform, :suite_name => suite_name)
      busser = bus_node(v_inst, suite_name)
      ui.info "#{ui.color('Kitchen:', :bold)} Running tests..."
      cmd = busser.run_cmd
      res = cmd.to_s.empty? ? true : v_inst.send(:direct_container_command, cmd, :live_stream => STDOUT)
      ui.info "\n  -> #{ui.color('Testing', :bold, :cyan)} #{name} suite #{suite_name} on platform #{platform}: #{res ? ui.color('SUCCESS!', :green, :bold) : ui.color('FAILED', :red)}"
      res
    end

    def destroy_node(platform, suite_name)
      if(options[:teardown])
        v_inst = vagabond_instance(:destroy, platform, :suite_name => suite_name)
        v_inst.send(:execute)
      end
    end

    def setup(name, action)
      @solo = name.to_s.strip.empty?
      @options = options.dup
      @vagabondfile = Vagabondfile.new(options[:vagabond_file], :allow_missing)
      setup_ui
      @internal_config = InternalConfiguration.new(@vagabondfile, ui, options)
      @name = name || action == :status ? name : discover_name
      load_kitchen_yml(@name) unless action == :status
      @action = action
    end

    # TODO: Make this traverse up if in cookbook subdir
    def discover_name
      name = nil
      if(File.exists?('metadata.rb'))
        m = Chef::Cookbook::Metadata.new
        m.from_file('metadata.rb')
        name = m.name
        unless(name)
          name = File.basename(File.dirname(File.expand_path(Dir.pwd)))
        end
      end
      raise "Failed to detect name of cookbook. Are we in the top directory?" unless name
      name
    end

    def configure_for(l_name, platform, suite_name, runlist, *args)
      dir = File.join(File.dirname(vagabondfile.store_path), ".vagabond/node_configs/#{l_name}")
      FileUtils.mkdir_p(dir)
      _args = [args.include?(:integration) ? :integration : nil].compact
      write_dna(l_name, suite_name, dir, platform, runlist, *_args) if args.include?(:dna)
      load_cookbooks(l_name, suite_name, dir, platform, runlist, *_args) if args.include?(:cookbooks)
      write_solo_config(dir) if args.include?(:cookbooks) && !args.include?(:integration)
      dir
    end

    def write_solo_config(dir)
      File.open(File.join(dir, 'solo.rb'), 'w') do |file|
        file.write("cookbook_path '#{File.join(dir, 'cookbooks')}'\n")
      end
    end

    def write_dna(l_name, suite_name, dir, platform, runlist, *args)
      key = args.include?(:integration) ? :integration_suites : :suites
      dna = Mash.new
      dna.merge!(platform_map[platform][:attributes] || Mash.new)
      suite = kitchen.suites.detect{|s|s.name == suite_name}
      if(suite)
        dna.merge!(suite.attributes)
      end
      dna[:run_list] = runlist
      File.open(File.join(dir, 'dna.json'), 'w') do |file|
        file.write(JSON.dump(dna))
      end
    end

    def cookbook_path
      if(@solo)
        vagabondfile.directory
      else
        require 'chef/knife'
        begin
          Chef::Knife.new.configure_chef
        rescue
          # ignore
        end
        Chef::CookbookLoader.new(
          Chef::Config[:cookbook_path]
        ).load_cookbooks[name].root_dir
      end
    end

    def custom_cheffile
      ui.warn "Installing Cooks with Librarian"
      contents = ['site "http://community.opscode.com/api/v1"']
      contents << "cookbook '#{name}', :path => '#{cookbook_path}'"
      contents << "cookbook 'minitest-handler'"
      contents.join("\n")
    end

    def load_cookbooks(l_name, suite_name, dir, platform, runlist, *_args)
      if(File.exists?(File.join(vagabondfile.directory, 'Berksfile')))
        berks_vendor
      else
        librarian_vendor
      end
    end
          
    def berks_vendor
      ui.info 'Cookbooks being vendored via berks'
      berk_uploader = Uploader::Berkshelf.new(
        vagabondfile.generate_store_path, options.merge(
          :ui => ui,
          :berksfile => File.join(vagabondfile.directory, 'Berksfile'),
          :chef_server_url => options[:knife_opts].to_s.split(' ').last
        )
      )
      berk_uploader.upload
    end

    def librarian_vendor
      ui.info 'Cookbooks being vendored with librarian'
      unless(File.exists?(cheffile = File.join(vagabondfile.directory, 'Cheffile')))
        File.open(cheffile = vagabond.generate_store_path, 'w') do |file|
          file.write custom_cheffile
        end
      end
      librarian_uploader = Uploader::Librarian.new(
        vagabondfile.generate_store_path, options.merge(
          :ui => ui,
          :cheffile => cheffile
        )
      )
      librarian_uploader.prepare
    end

    def bus_node(v_inst, suite_name)
      test_path = options[:cluster] ? 'test/cluster' : 'test/integration'
      unless(::Kitchen::Busser::DEFAULT_TEST_ROOT == c_path = File.join(cookbook_path, test_path))
        ::Kitchen::Busser.send(:remove_const, :DEFAULT_TEST_ROOT)
        ::Kitchen::Busser.const_set(:DEFAULT_TEST_ROOT, c_path)
      end
      busser = ::Kitchen::Busser.new(suite_name)
      ui.info "#{ui.color('Kitchen:', :bold)} Setting up..."
      %w(setup_cmd sync_cmd).each do |cmd|
        com = busser.send(cmd)
        next if com.to_s.empty?
        v_inst.send(:direct_container_command, com)
      end
      busser
    end

    def vagabond_instance(action, platform, args={})
      options[:disable_name_validate] = true
      v = Vagabond.new
      v.options = options
      v.send(:setup, action, [name, platform, args[:suite_name]].compact.join('-'),
        :ui => ui,
        :template => platform_map[platform][:template],
        :disable_name_validate => true,
        :ui => ui
      )
      v.internal_config.force_bases = platform_map[platform][:template]
      v.internal_config.ensure_state
      v.mappings_key = :test_mappings
      v.config = Mash.new(
        :template => platform_map[platform][:template],
        :run_list => args[:run_list]
      )
      v.lxc = Lxc.new(
        v.internal_config[v.mappings_key][v.name]
      ) if v.internal_config[v.mappings_key][v.name]
      v
    end

    def load_kitchen_yml(name)
      @kitchen = ::Kitchen::Config.new(
        :kitchen_root => cookbook_path,
        :test_base_path => File.join(cookbook_path, 'test/integration'),
        :loader => ::Kitchen::Loader::YAML.new(
          File.join(cookbook_path, '.kitchen.yml')
        )
      )
    end

    def platform_map
      @platform_map ||= Mash[
        *(
          kitchen.platforms.map do |plat|
            [
              plat.name, Mash.new(
                :template => plat.name.gsub('.', '').gsub('-', '_'),
                :run_list => plat.run_list,
                :attributes => plat.attributes
              )
            ]
          end.flatten
        )
      ]
    end

    def generate_runlist(platform, suite)
      unless(platform_map[platform])
        raise "Invalid platform #{platform}. Valid: #{platform_map.keys.sort.join(', ')}"
      end
      r = platform_map[platform][:run_list]
      kitchen_suite = kitchen.suites.detect do |k_s|
        k_s.name == suite
      end
      if(kitchen_suite && kitchen_suite.run_list)
        r |= kitchen_suite.run_list
      end
      r.uniq
    end

    def validate_platform!(plat)
      unless(platform_map[plat])
        ui.fatal "Requested platform does not exist: #{ui.color(plat, :red)}"
        ui.info "  -> Available platforms: #{platform_map.keys.sort.join(', ')}"
        exit EXIT_CODES[:kitchen_invalid_platform]
      end
    end
  end
end
