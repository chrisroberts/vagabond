require 'thor'
require 'chef'
require 'kitchen/busser'

%w(helpers vagabondfile vagabond server helpers/cheffile_loader).each do |dep|
  require "vagabond/#{dep}"
end

module Vagabond
  class Kitchen < Thor
    
    include Thor::Actions
    include Helpers

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

    desc 'test COOKBOOK', 'Run test kitchen on COOKBOOK'
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
      :desc => 'Build test nodes in parallel'
    )
    method_option(:suites,
      :type => :string,
      :desc => 'Specify suites to test [suite1,suite2,...]'
    )
    def test(cookbook)
      setup(cookbook, :test)
      ui.info "#{ui.color('Vagabond:', :bold)} - Kitchen testing for cookbook #{ui.color(name, :cyan)}"
      results = Mash.new
      platforms = [options[:platform] || platform_map.keys].flatten
      if(options[:cluster])
        ui.info ui.color("  -> Cluster Testing #{options[:cluster]}!", :yellow)
        if(kitchen[:clusters].nil? || kitchen[:clusters][options[:cluster]].nil?)
          ui.fatal "Requested cluster is not defined: #{options[:cluster]}"
          exit EXIT_CODES[:cluster_invalid]
        end
        serv = Server.new
        serv.options = options
        serv.auto_upload # upload everything : make optional?
        suites = kitchen[:clusters][options[:cluster]]
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
    end
    
    protected

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
      @options = options.dup
      @vagabondfile = Vagabondfile.new(options[:vagabond_file])
      setup_ui
      @name = name
      @action = action
      load_kitchen_yml
    end

    def configure_for(l_name, platform, suite_name, runlist, *args)
      dir = File.join(File.dirname(vagabondfile.path), ".vagabond/node_configs/#{l_name}")
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
      dna.merge!(platform_map[platform][:attributes] || {})
      s_args = kitchen[:suites].detect{|s|s[:name] == suite_name}
      if(s_args)
        dna.merge!(s_args)
      end
      dna[:run_list] = runlist
      File.open(File.join(dir, 'dna.json'), 'w') do |file|
        file.write(JSON.dump(dna))
      end
    end

    def cookbook_path
      Chef::CookbookLoader.new(
        File.join(File.dirname(vagabondfile.path), 'cookbooks')
      ).load_cookbooks[name].root_dir
    end
    
    def load_cookbooks(l_name, suite_name, dir, platform, runlist, *_args)
      contents = ['site "http://community.opscode.com/api/v1"']
      contents << "cookbook '#{name}', :path => '#{cookbook_path}'"
      contents << "cookbook 'minitest-handler'"
      # TODO - Customs from kitchen. Customs from root. Customs from cookbook
      File.open(File.join(dir, 'Cheffile'), 'w') do |file|
        file.write(contents.join("\n"))
      end
      com = "librarian-chef update"
      debug(com)
      c = Mixlib::ShellOut.new(com, :live_stream => options[:debug], :cwd => dir)
      c.run_command
      c.error!
    end

    def bus_node(v_inst, suite_name)
      unless(::Kitchen::Busser::DEFAULT_TEST_ROOT == c_path = File.join(cookbook_path, 'test/integration'))
        ::Kitchen::Busser.send(:remove_const, :DEFAULT_TEST_ROOT)
        ::Kitchen::Busser.const_set(:DEFAULT_TEST_ROOT, File.join(cookbook_path, 'test/integration'))
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

    def load_kitchen_yml
      y_path = File.join(
        File.dirname(vagabondfile.path), 'cookbooks', name, '.kitchen.yml'
      )
      if(File.exists?(y_path))
        @kitchen = Mash.new(YAML.load(File.read(y_path)))
      else
        ui.fatal "Cookbook #{name} does not have a .kitchen.yml file defined!"
        ui.info ui.color("  -> Path: #{y_path}", :red)
        exit EXIT_CODES[:kitchen_missing_yml]
      end
    end

    def platform_map
      @platform_map ||= Mash.new(Hash[*(
          kitchen[:platforms].map do |plat|
            [
              plat[:name], Mash.new(
                  :template => plat[:driver_config][:box].scan(
                    %r{([^-]+-[^-]+)$}
                  ).flatten.first.to_s.gsub('.', '').gsub('-', '_'),
                  :run_list => plat[:run_list],
                  :attributes => plat[:attributes]
              )
            ]
          end.flatten
      )])
    end

    def generate_runlist(platform, suite)
      r = platform_map[platform][:run_list]
      kitchen_suite = kitchen[:suites].detect do |k_s|
        k_s[:name] == suite
      end
      if(kitchen_suite && kitchen_suite[:run_list])
        r |= kitchen_suite[:run_list]
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
