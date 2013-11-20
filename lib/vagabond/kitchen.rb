#encoding: utf-8

require 'chef'
require 'kitchen'
require 'kitchen/busser'
require 'kitchen/loader/yaml'
require 'vagabond/monkey/kitchen_config'

require 'vagabond/helpers/server'
require 'vagabond/vagabond'
require 'vagabond/server'

module Vagabond
  class Kitchen < Vagabond

    NAME_JOINER = '_platsuite_'

    include Vagabond::Helpers::Server

    attr_reader :platform_map

    def install_actions
    end

    def test(name=nil)
      name = discover_name unless name
      ui.info "#{ui.color('Vagabond:', :bold)} - Kitchen testing for cookbook #{ui.color(name, :cyan)}"
      current_platforms.each do |platform|
        if(options[:cluster])
          server_init!
          vagabondfile[:clusters][options[:cluster]].map do |node_name|
            platform, suite = node_name.split(NAME_JOINER)
            run_action(:up, node_name)
            node = load_node(node_name)
            [node, platform, suite]
          end.map do |test_args|
            test_node(*test_args)
            test_args
          end.map do |test_args|
            run_action(:destroy, test_args.first)
          end
        else
          current_suites.each do |suite|
            key = generate_name(platform, suite)
            run_action(:up, key)
            node = load_node(key)
            solo_provision(node, platform, suite)
            test_node(node, platform, suite)
            run_action(:destroy, key)
          end
        end
      end
    end

    def current_platforms
      [options[:platform] || platform_map.keys].flatten
    end

    def current_suites
      if(options[:suites])
        options[:suites].split(',')
      else
        kitchen.suites.map(&:name)
      end
    end

    protected

    def solo_provision(node, platform, suite_name)
      run_list = generate_runlist(platform, suite_name)
      ui.info ui.color("  -> Provisioning suite #{suite_name} on platform: #{platform}", :cyan)
      dir = File.join(File.dirname(vagabondfile.store_path), ".vagabond/node_configs/#{l_name}")
      FileUtils.mkdir_p(dir)
      write_dna(platform, suite_name, node.run_list, dir)
      write_solo_config(dir)
      node.run_solo(dir)
    end

    def write_solo_config(directory)
      File.open(File.join(directory, 'solo.rb'), 'w') do |file|
        file.write("cookbook_path '#{File.join(vagabondfile.store_path, 'cookbooks')}'\n")
      end
      dir
    end

    def write_dna(platform, suite_name, run_list, directory)
      dna = Mash.new
      dna.merge!(platform_map[platform][:attributes] || Mash.new)
      suite = kitchen.suites.detect{|s|s.name == suite_name}
      if(suite)
        dna.merge!(suite.attributes)
      end
      dna[:run_list] = run_list
      File.open(path = File.join(dir, 'dna.json'), 'w') do |file|
        file.write(JSON.dump(dna))
      end
      path
    end

    def test_node(node, platform, suite_name)
      busser = bus_node(node, suite_name)
      if(busser)
        ui.info "#{ui.color('Kitchen:', :bold)} Running tests..."
        cmd = busser.run_cmd
        res = cmd.to_s.empty? ? true : node.run_command, cmd, :live_stream => ui.live_stream)
        ui.info "\n  -> #{ui.color('Testing', :bold, :cyan)} #{name} suite #{suite_name} on platform #{platform}: #{res ? ui.color('SUCCESS!', :green, :bold) : ui.color('FAILED', :red)}"
        res
      else
        ui.info "#{ui.color('Kitchen:', :bold)} No tests found."
        :no_tests
      end
    end

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

    def generate_name(platform, suite)
      [platform, suite].join(NAME_JOINER)
    end

    def populate_vagabondfile(platform)
      kitchen.suites.each do |suite|
        vagabondfile[:nodes]["#{platform}_#{suite.name}"] = Mash.new(
          :run_list => generate_runlist(platform, suite),
          :attributes => generate_attributes(platform, suite),
          :template => platform_map[platform][:template]
        )
      end
      kitchen.clusters.each do |cluster_name, cluster_suites|
        vagabondfile[:clusters]["#{platform}_#{cluster_name}"] = cluster_suites.map do |name|
          "#{platform}_#{name}"
        end
      end
    end

    def cookbook_path
      cookbook = Chef::CookbookLoader.new(
        Chef::Config[:cookbook_path]
      ).load_cookbooks[name]
      if(cookbook)
        cookbook.root_dir
      else
        discover_name
        Dir.pwd
      end
    end

    def custom_cheffile
      ui.warn "Installing Cookbooks with Librarian"
      contents = ['site "http://community.opscode.com/api/v1"']
      contents << "cookbook '#{name}', :path => '#{cookbook_path}'"
      contents << "cookbook 'minitest-handler'"
      contents.join("\n")
    end

    def load_cookbooks(*args)
      if(File.exists?(File.join(vagabondfile.directory, 'Cheffile')) && !options[:force_berkshelf])
        uploader = librarian_vendor(args.include?(:upload))
      else
        uploader = berks_vendor(args.include?(:upload))
      end
      uploader
    end

    def berks_vendor(upload=false)
      ui.info 'Cookbooks being vendored via berks'
      if(vagabondfile[:local_chef_server][:berkshelf].is_a?(Hash))
        berks_opts = vagabondfile[:local_chef_server][:berkshelf][:options]
        berks_path = vagabondfile[:local_chef_server][:berkshelf][:path]
      end
      berk_uploader = Uploader::Berkshelf.new(
        vagabondfile, vagabondfile.store_path, options.merge(
          :ui => ui,
          :berksfile => File.join(vagabondfile.directory, berks_path || 'Berksfile'),
          :chef_server_url => options[:knife_opts].to_s.split(' ').last,
          :berks_opts => berks_opts
        )
      )
      upload ? berk_uploader.upload : berk_uploader.prepare
      berk_uploader
    end

    def librarian_vendor(upload=false)
      ui.info 'Cookbooks being vendored with librarian'
      unless(File.exists?(cheffile = File.join(vagabondfile.directory, 'Cheffile')))
        ui.warn 'Writing custom Cheffile to provide any required dependency resolution'
        File.open(cheffile = File.join(vagabondfile.store_path, 'Cheffile'), 'w') do |file|
          file.write custom_cheffile
        end
      end
      librarian_uploader = Uploader::Librarian.new(
        vagabondfile, vagabondfile.store_path,
        options.merge(
          :ui => ui,
          :cheffile => cheffile
        )
      )
      upload ? librarian_uploader.upload : librarian_uploader.prepare
      librarian_uploader
    end

    def bus_node(node, suite_name)
      test_path = options[:cluster] ? 'test/cluster' : 'test/integration'
      if(File.directory?(book_path = File.join(cookbook_path, test_path)))
        unless(::Kitchen::Busser::DEFAULT_TEST_ROOT == book_path)
          ::Kitchen::Busser.send(:remove_const, :DEFAULT_TEST_ROOT)
          ::Kitchen::Busser.const_set(:DEFAULT_TEST_ROOT, book_path)
        end
        busser = ::Kitchen::Busser.new(suite_name)
        ui.info "#{ui.color('Kitchen:', :bold)} Setting up..."
        %w(setup_cmd sync_cmd).each do |cmd|
          com = busser.send(cmd)
          next if com.to_s.empty?
          node.run_command(com)
        end
        busser
      end
    end

    def kitchen
      unless(@kitchen)
        @kitchen = ::Kitchen::Config.new(
          :kitchen_root => cookbook_path,
          :test_base_path => File.join(cookbook_path, 'test/integration'),
          :loader => ::Kitchen::Loader::YAML.new(
            File.join(cookbook_path, '.kitchen.yml')
          )
        )
      end
      @kitchen
    end

    def platform_map
      @platform_map ||= Mash[
        *(
          kitchen.platforms.map do |plat|
            if(defined?(::Kitchen::Platform::Cheflike))
              plat.extend(::Kitchen::Platform::Cheflike)
            end
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
      validate_platform!(platform)
      run_list = platform_map[platform][:run_list]
      kitchen_suite = kitchen.suites.detect do |_suite|
        _suite.name == suite
      end
      if(defined?(::Kitchen::Suite::Cheflike))
        kitchen_suite.extend(::Kitchen::Suite::Cheflike)
      end
      if(kitchen_suite && kitchen_suite.run_list)
        run_list |= kitchen_suite.run_list
      end
      run_list.uniq
    end

    def generate_attributes(platform, suite)
      validate_platform!(platform)
      attributes = platform_map[platform][:attributes]
      kitchen_suite = kitchen.suites.detect do |_suite|
        _suite.name == suite
      end
      if(defined?(::Kitchen::Suite::Cheflike))
        kitchen_suite.extend(::Kitchen::Suite::Cheflike)
      end
      if(kitchen_suite && kitchen_suite.attributes)
        attributes = Chef::Mixin::DeepMerge.merge(attributes, kitchen_suite.attributes)
      end
      attributes
    end

    def validate_platform!(plat)
      unless(platform_map[plat])
        ui.fatal "Requested platform does not exist: #{ui.color(plat, :red)}"
        ui.info "  -> Available platforms: #{platform_map.keys.sort.join(', ')}"
        raise VagabondError::KitchenInvalidPlatform.new(plat)
      end
    end
  end
end
