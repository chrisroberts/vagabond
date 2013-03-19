require 'vagabond/helpers'
require 'vagabond/vagabondfile'
require 'chef'
require 'kitchen/busser'
require 'vagabond/helpers/cheffile_loader'

module Vagabond
  class Kitchen

    include Helpers

    attr_reader :kitchen
    attr_reader :platform_map
    attr_reader :vagabondfile
    attr_reader :ui
    attr_reader :name
    attr_reader :action
    
    def initialize(action, name_args)
      @vagabondfile = Vagabondfile.new(Config[:vagabond_file])
      setup_ui
      if(name_args.empty?)
        ui.fatal 'Must provide a cookbook name for testing!'
        exit EXIT_CODES[:kitchen_no_cookbook_arg]
      elsif(name_args.size > 2)
        ui.fatal 'Too many arguments provided!'
        exit EXIT_CODES[:kitchen_too_many_args]
      end
      if(name_args.size == 1)
        @action = :cookbook
        @name = name_args.first
      else
        @action, @name = name_args
      end
      load_kitchen_yml
      Config[:teardown] = true if Config[:teardown].nil?
    end

    # TODO: We need platform + suite for teardown proper
    def teardown(platform=nil)
      ui.info "#{ui.color('Vagabond:', :bold)} - Kitchen teardown for cookbook #{ui.color(name, :red)}"
      plats = [platform || Config[:platform] || platform_map.keys].flatten
      plats.each do |plat|
        validate_platform!(plat)
        ui.info ui.color("  -> Tearing down platform: #{plat}", :red)
        vagabond_instance(:destroy, plat).send(:execute)
        ui.info ui.color("  -> Teardown of platform: #{plat} - COMPLETE!", :red)
      end
    end

    def cookbook
      ui.info "#{ui.color('Vagabond:', :bold)} - Kitchen testing for cookbook #{ui.color(name, :cyan)}"
      plats = [Config[:platform] || platform_map.keys].flatten
      plats.each do |plat|
        validate_platform!(plat)
        if(Config[:integration])
          integration_tests(plat)
        else
          suite_tests(plat)
        end
      end
    end
    
    protected

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
      c = Mixlib::ShellOut.new(com, :live_stream => Config[:debug], :cwd => dir)
      c.run_command
      c.error!
    end
 
    def suite_tests(plat)
      generate_runlists(plat, Config[:suite]).each do |s_name, s_runlist|
        ui.info ui.color("  -> Running #{s_name} on platform: #{plat}", :cyan)
        v_inst = vagabond_instance(:create, plat, :suite_name => s_name)
        v_inst.send(:execute)
        solo_path = configure_for(v_inst.name, plat, s_name, s_runlist, :dna, :cookbooks)
        res = v_inst.send(:provision_solo, solo_path)
        if(res)
          ui.info ui.color('  -> PROVISION COMPLETE', :green)
          busser = bus_node(v_inst, s_name)
          ui.info "#{ui.color('Kitchen:', :bold)} Running tests..."
          res = v_inst.send(:direct_container_command, busser.run_cmd, :live_stream => STDOUT)
        end
        if(false && Config[:teardown])
          v_inst.action = :destroy
          v_inst.send(:execute)
        end
        ui.info "\n  -> #{ui.color('Testing', :bold, :cyan)} #{name} suite #{s_name} on platform #{plat}: #{res ? ui.color('SUCCESS!', :green, :bold) : ui.color('FAILED', :red)}"
      end
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

    def cluster_tests
      generate_runlists(plat, Config[:suite], :integration).each do |s_name, s_runlist|
        ui.info ui.color("  -> Running #{s_name} on platform: #{plat}", :cyan)
        if(vagabond_instance(:up, plat, :suite_name => s_name, :run_list => s_runlist).send(:execute))
          ui.info ui.color("  -> Running #{s_name} on platform: #{plat} - COMPLETE!", :cyan)
        else
          ui.info ui.color("  -> Running #{s_name} on platform: #{plat} - FAILED!", :red)
        end
        teardown(plat)
      end
    end
    
    def vagabond_instance(action, platform, args={})
      Config[:disable_name_validate] = true
      v = Vagabond.new(action, [[name, platform, args[:suite_name]].compact.join('-')],
        :ui => ui,
        :template => platform_map[platform][:template]
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

    def generate_runlists(platform, suite, *args)
      r = platform_map[platform][:run_list]
      lists = Mash.new
      if(kitchen[:suites])
        s = suite ? kitchen[:suites].detect{|su| su[:name] == suite} : kitchen[:suites]
        [s].flatten.each do |_suite|
          gen_suite = r | _suite[:run_list]
          gen_suite.uniq
          lists[_suite[:name]] = gen_suite
        end
      else
        lists[:default] = r
      end
      lists
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
