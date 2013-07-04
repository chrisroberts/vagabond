#encoding: utf-8
require 'digest/sha2'
require 'json'
require 'vagabond/helpers'
require 'vagabond/constants'
require 'chef/mixin/deep_merge'

module Vagabond
  class InternalConfiguration

    include Helpers
    
    attr_reader :config
    attr_reader :ui
    attr_reader :options
    attr_accessor :force_bases
    
    def initialize(vagabondfile, ui, options, args={})
      @vagabondfile = vagabondfile
      @checksums = Mash.new
      @ui = ui
      @options = options
      create_store
      load_existing
      @config = Mash.new(
        :mappings => Mash.new,
        :template_mappings => Mash.new,
        :test_mappings => Mash.new,
        :spec_mappings => Mash.new,
        :spec_clusters => Mash.new
      ).merge(config)
      @force_bases = args[:force_bases] || []
      ensure_state
      make_knife_config_if_required
    end

    def ensure_state
      check_bases_and_customs!
      if(solo_needed?)
        store_checksums
        write_dna_json
        write_solo_rb
        install_cookbooks
        run_solo if solo_needed?
      end
    end

    def check_bases_and_customs!
      if(File.exists?(dna_path))
        dna = Mash.new(JSON.load(File.read(dna_path)))
        %w(bases customs).each do |key|
          if(dna[:vagabond][key])
            dna[:vagabond][key].each do |n, opts|
              options[:force_solo] = true unless Lxc.new(n).exists?
            end
          end
        end
      end
    end

    def [](k)
      @config[k]
    end

    def []=(k,v)
      @config[k] = v
    end
    
    def create_store
      FileUtils.mkdir_p(store_path)
    end

    def load_existing(file=nil)
      if(File.exists?(path = File.join(store_path, 'vagabond.json')))
        if(file)
          file.rewind
          content = file.read
        else
          content = File.read(path)
        end
        if(content.strip.empty?)
          config = Mash.new
        else
          config = Mash.new(
            JSON.load(content)
          )
        end
        @config = Chef::Mixin::DeepMerge.merge(config, @config)
      else
        @config = Mash.new
      end
    end

    def store_path
      path = File.join(File.dirname(@vagabondfile.store_path), '.vagabond')
      unless(File.directory?(path))
        FileUtils.mkdir_p(path)
      end
      path
    end

    def dna_path
      File.join(store_path, 'dna.json')
    end

    def solo_path
      File.join(store_path, 'solo.rb')
    end

    def write_dna_json
      conf = Mash.new(:bases => Mash.new, :customs => Mash.new)
      (Array(@vagabondfile[:nodes]).map(&:last).map{|i| i[:template]}.compact + Array(force_bases)).uniq.each do |t|
        conf[:bases][t] = Mash.new(:enabled => true) if BASE_TEMPLATES.include?(t.to_s)
      end
      Array(@vagabondfile[:templates]).each do |t_name, opts|
        if(BASE_TEMPLATES.include?(opts[:base].to_s))
          conf[:bases][opts[:base]] = Mash.new(:enabled => true)
          if(opts.has_key?(:memory) && !opts[:memory].is_a?(Hash))
            opts[:memory][:ram] = opts[:memory].to_s
          end
          conf[:customs][generated_name(t_name)] = opts
          config[:template_mappings][t_name] = generated_name(t_name)
        else
          ui.fatal "Invalid base template encountered: #{t_name}"
          ui.info ui.color("  -> Valid base templates: #{BASE_TEMPLATES.sort.join(', ')}", :red)
          raise VagabondError::InvalidBaseTemplate.new(t_name)
        end
      end
      File.open(dna_path, 'w') do |file|
        file.write(
          JSON.dump(
            :vagabond => conf,
            :run_list => %w(recipe[vagabond])
          )
        )
      end
      save
    end

    def write_solo_rb
      File.open(solo_path, 'w') do |file|
        file.write("\nfile_cache_path \"#{cache_path}\"\ncookbook_path \"#{cookbook_path}\"\n")
      end
    end

    def store_checksums
      [dna_path, solo_path].each do |path|
        @checksums[path] = get_checksum(path)
      end
    end

    def get_checksum(path)
      if(File.exists?(path))
        s = Digest::SHA256.new
        s << File.read(path)
        s.hexdigest
      else
        ''
      end
    end

    def solo_needed?
      if(options[:force_solo])
        true
      elsif(options[:disable_solo])
        false
      else
        [dna_path, solo_path].detect do |path|
          @checksums[path] != get_checksum(path)
        end
      end
    end
    
    def cache_path
      unless(@cache_path)
        FileUtils.mkdir_p(@cache_path = File.join(store_path, 'chef_cache'))
      end
      @cache_path
    end

    def cookbook_path
      unless(@cookbook_path)
        FileUtils.mkdir_p(@cookbook_path = File.join(store_path, 'cookbooks'))
      end
      @cookbook_path
    end

    def install_cookbooks
      begin
        FileUtils.copy(
          File.expand_path(File.join(File.dirname(__FILE__), 'Cheffile')),
          File.join(File.dirname(cookbook_path), 'Cheffile')
        )
        com = 'librarian-chef update'
        debug(com)
        ui.info ui.color('Fetching required cookbooks...', :yellow)
        cmd = Mixlib::ShellOut.new(com,
          :timeout => 300,
          :live_stream => options[:debug],
          :cwd => File.dirname(cookbook_path)
        )
        cmd.run_command
        cmd.error!
        ui.info ui.color('  -> COMPLETE!', :yellow)
      rescue => e
        ui.info e.to_s
        ui.info ui.color('  -> FAILED!', :red, :bold)
        raise VagabondError::LibrarianHostInstallFailed.new(e)
      end
    end
    
    def run_solo
      begin
        ui.info ui.color('Ensuring expected system state (creating required base containers)', :yellow)
        ui.info ui.color('   - This can take a while on first run or new templates...', :yellow)
        com = "#{options[:sudo]}chef-solo -j #{File.join(store_path, 'dna.json')} -c #{File.join(store_path, 'solo.rb')}"
        debug(com)
        cmd = Mixlib::ShellOut.new(com, :timeout => 12000, :live_stream => options[:debug])
        cmd.run_command
        cmd.error!
        ui.info ui.color('  -> COMPLETE!', :yellow)
      rescue => e
        ui.info e.to_s
        FileUtils.rm(solo_path)
        ui.info ui.color('  -> FAILED!', :red, :bold)
        raise VagabondError::HostProvisionFailed.new(e)
      end
    end

    def config_path
      File.join(store_path, 'vagabond.json')
    end
    
    def save
      mode = File.exists?(config_path) ? 'r+' : 'w+'
      File.open(config_path, mode) do |file|
        file.flock(File::LOCK_EX)
        file.rewind
        if(sha = file_changed?(file.path))
          @checksums[file.path] = sha
          load_existing(file)
        end
        file.rewind
        file.write(JSON.pretty_generate(@config))
        file.truncate(file.pos)
      end
    end

    def knife_config_available?
      if(File.exists?(File.join(store_path, 'knife.rb')))
        false
      else
        cwd = @vagabondfile.directory.split('/')
        found = false
        until(found || cwd.empty?)
          found = File.exists?(File.join(*(cwd + ['.chef/knife.rb'])))
          cwd.pop
        end
        found
      end
    end

    def file_changed?(path)
      checksum = get_checksum(path)
      checksum unless @checksums[path] == checksum
     end
    
    def make_knife_config_if_required(force=false)
      if((@vagabondfile[:local_chef_server] && @vagabondfile[:local_chef_server][:enabled]) || force)
        unless(knife_config_available?)
          store_dir = File.dirname(store_path)
          k_dir = File.join(store_dir, '.chef')
          FileUtils.mkdir_p(k_dir)
          unless(File.exists?(knife = File.join(k_dir, 'knife.rb')))
            File.open(knife, 'w') do |file|
              file.write <<-EOF
node_name 'dummy'
client_key File.join(File.dirname(__FILE__), 'client.pem')
validation_client_name 'dummy-validator'
validation_key File.join(File.dirname(__FILE__), 'validation.pem')
cookbook_path ['#{%w(cookbooks site-cookbooks).map{|dir|File.join(@vagabondfile.directory, dir)}.join(',')}']
EOF
            end
          end
          %w(client.pem validation.pem).each do |name|
            unless(File.exists?(pem = File.join(k_dir, name)))
              %x{openssl genrsa -out #{pem} 2048}
            end
          end
        end
      end
    end
  end
end
