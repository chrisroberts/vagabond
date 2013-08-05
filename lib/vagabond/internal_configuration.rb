#encoding: utf-8
require 'json'
require 'digest/sha2'

require 'chef'
require 'chef/mixin/deep_merge'

require 'vagabond/helpers'
require 'vagabond/constants'
require 'vagabond/version'

module Vagabond
  class InternalConfiguration

    class << self
      attr_accessor :host_provisioned

      def host_provisioned?
        !!@host_provisioned
      end
    end

    include Helpers
    
    attr_reader :config
    attr_reader :ui
    attr_reader :options
    attr_accessor :force_bases
    
    def initialize(vagabondfile, ui, options, args={})
      @vagabondfile = vagabondfile
      @checksums = Mash.new
      if(ui)
        @ui = ui
      else
        @ui = Logger.new('/dev/null')
        @ui.instance_eval do
          def color(*args)
          end
        end
      end
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
      unless(self.class.host_provisioned?)
        install_cookbooks
      end
      check_bases_and_customs!
      set_templates
      store_checksums
      write_dna_json
      write_solo_rb
      if(solo_needed?)
        run_solo
      else
        self.class.host_provisioned = true
      end
    end

    def set_templates
      unless(Vagabond.const_defined?(:BASE_TEMPLATES))
        Vagabond.const_set(
          :BASE_TEMPLATES, cookbook_attributes(:vagabond).bases.keys
        )
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
        if(dna[:vagabond][:server])
          srv_name = [
            cookbook_attributes(:vagabond).server.prefix,
            dna[:vagabond][:server][:erchefs].first.to_s.gsub('.', '_')
          ].join
          options[:force_solo] = true unless Lxc.new(srv_name).exists?
        end
        unless(Lxc.new(cookbook_attributes(:vagabond).server.zero_lxc_name).exists?)
          options[:force_solo] = true
        end
      end
    end

    def [](k)
      @config[k]
    end

    def []=(k,v)
      @config[k] = v
      save
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
        conf[:bases][t] = Mash.new(:enabled => true) if Vagabond::BASE_TEMPLATES.include?(t.to_s)
      end
      Array(@vagabondfile[:templates]).each do |t_name, opts|
        if(Vagabond::BASE_TEMPLATES.include?(opts[:base].to_s))
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
      if(@vagabondfile.local_chef_server? && !@vagabondfile[:local_chef_server][:zero])
        version = @vagabondfile[:local_chef_server][:version] || cookbook_attributes(:vagabond).server.erchefs
        conf[:server] = Mash.new
        conf[:server][:erchefs] = [version].flatten.uniq
      end
      conf[:host_cookbook_store] = cookbook_path
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

    def cheffile_path
      File.expand_path(
        File.join(File.dirname(__FILE__), 'Cheffile')
      )
    end

    def vendor_cheffile_path
      File.expand_path(
        File.join(File.dirname(cookbook_path), 'Cheffile')
      )
    end
    
    def cookbook_vendor_required?
      need_vendor = !File.exists?(vendor_cheffile_path)
      need_vendor ||= get_checksum(vendor_cheffile_path) != get_checksum(cheffile_path)
      spec = Gem::Specification.find_by_name('vagabond', ::Vagabond::VERSION.version)
      if(spec.respond_to?(:git_version) && ::Vagabond::VERSION.segments.last.odd?)
        if(self[:dev_mode] && self[:dev_mode][:vendor_cookbook_check])
          elapsed_time = Time.now.to_i - self[:dev_mode][:vendor_cookbook_check].to_i
          need_vendor = elapsed_time > (ENV['VAGABOND_DEV_VENDOR_EVERY'] || 3600).to_i
        end
        self[:dev_mode] ||= Mash.new
        self[:dev_mode][:vendor_cookbook_check] = Time.now.to_i if need_vendor
      end
      unless(ENV['VAGABOND_FORCE_VENDOR'].to_s == 'false')
        ENV['VAGABOND_FORCE_VENDOR'] || need_vendor
      end
    end
    
    def install_cookbooks
      begin
        if(cookbook_vendor_required?)
          FileUtils.copy(cheffile_path, vendor_cheffile_path)
          ui.info ui.color('Fetching required cookbooks...', :yellow)
          cmd = build_command('librarian-chef update', :cwd => File.dirname(cookbook_path))
          cmd.run_command
          cmd.error!
          ui.info ui.color('  -> COMPLETE!', :yellow)
        else
          cmd = build_command('librarian-chef install', :cwd => File.dirname(cookbook_path))
          cmd.run_command
          cmd.error!
        end
      rescue => e
        ui.info e.to_s
        ui.info ui.color('  -> FAILED!', :red, :bold)
        raise VagabondError::LibrarianHostInstallFailed.new(e)
      end
    end
    
    def run_solo
      unless(self.class.host_provisioned?)
        begin
          ui.info ui.color('Ensuring expected system state (creating required base containers)', :yellow)
          ui.info ui.color('   - This can take a while on first run or new templates...', :yellow)
          cmd = build_command("#{options[:sudo]}chef-solo -j #{File.join(store_path, 'dna.json')} -c #{File.join(store_path, 'solo.rb')}")
          cmd.run_command
          cmd.error!
          ui.info ui.color('  -> COMPLETE!', :yellow)
          self.class.host_provisioned = true
        rescue => e
          ui.info e.to_s
          FileUtils.rm(solo_path)
          ui.info ui.color('  -> FAILED!', :red, :bold)
          raise VagabondError::HostProvisionFailed.new(e)
        end
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

    def cookbook_attributes(cookbook, namespace=true)
      @_attr_cache ||= Mash.new
      unless(@_attr_cache[cookbook])
        node = Chef::Node.new
        %w(rb json js).each do |ext|
          Dir.glob(File.join(cookbook_path, cookbook.to_s, 'attributes', "*.#{ext}")).each do |attr_file|
            node.from_file(attr_file)
          end
        end
        if(namespace)
          key = namespace.is_a?(String) || namespace.is_a?(Symbol) ? namespace : cookbook
          @_attr_cache[cookbook] = node.attributes.send(key)
        else
          @_attr_cache[cookbook] = node.attributes
        end
      end
      @_attr_cache[cookbook]
    end
    
    def make_knife_config_if_required(force=false)
      if(@vagabondfile.local_chef_server? || force)
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
