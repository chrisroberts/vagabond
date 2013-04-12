require 'digest/sha2'
require 'json'
require 'vagabond/helpers'
require 'vagabond/constants'

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
        :test_mappings => Mash.new
      ).merge(config)
      @force_bases = args[:force_bases] || []
      ensure_state
    end

    def ensure_state
      if(solo_needed?)
        store_checksums
        write_dna_json
        write_solo_rb
        run_solo if solo_needed?
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

    def load_existing
      if(File.exists?(path = File.join(store_path, 'vagabond.json')))
        @config = Mash.new(
          JSON.load(
            File.read(path)
          )
        )
      else
        @config = Mash.new
      end
    end

    def store_path
      FileUtils.mkdir_p(
        File.join(
          File.dirname(@vagabondfile.path), '.vagabond'
        )
      )
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
          ui.fatal "Invalid base template encountered: #{t}"
          ui.info ui.color("  -> Valid base templates: #{BASE_TEMPLATES.sort.join(', ')}", :red)
          exit EXIT_CODES[:invalid_base_template]
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
      File.expand_path(
        File.join(
          File.dirname(__FILE__), 'cookbooks'
        )
      )
    end
    
    def run_solo
      begin
        ui.info ui.color('Ensuring expected system state (creating required base containers)', :yellow)
        ui.info ui.color('   - This can take a while...', :yellow)
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
        exit # TODO: Make better
      end
    end
    
    def save
      File.open(File.join(store_path, 'vagabond.json'), 'w') do |file|
        file.write(JSON.dump(@config))
      end
    end

  end
end
