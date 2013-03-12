require 'digest/sha2'

module Vagabond
  class InternalConfiguration

    attr_reader :config
    attr_reader :ui
    
    def initialize(v_config, ui)
      @v_config = v_config
      @config = Mash.new(:mappings => Mash.new)
      @checksums = Mash.new
      @ui = ui
      create_store
      load_existing
      store_checksums
      write_dna_json
      write_solo_rb
      run_solo if solo_needed?
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
      end
    end

    def store_path
      FileUtils.mkdir_p(
        File.join(
          File.dirname(@v_config.path), '.vagabond'
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
      templates = @v_config.config[:boxes].map(&:last).map{|i| i[:template]}.compact.uniq
      templates = Hash[*(
          templates.map do |t|
            if(@v_config.config[:templates] && @v_config[:templates][t])
              [t, @v_config.config[:templates][t]]
            else
              [t, nil]
            end
          end
      ).flatten]
      File.open(dna_path, 'w') do |file|
        file.write(
          JSON.dump(
            :vagabond => {
              :bases => templates
            },
            :run_list => %w(recipe[vagabond])
          )
        )
      end
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
      if(Config[:force_solo])
        true
      elsif(Config[:disable_solo])
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
      ui.info ui.color('Ensuring expected system state...', :yellow)
      com = "#{Config[:sudo]}chef-solo -j #{File.join(store_path, 'dna.json')} -c #{File.join(store_path, 'solo.rb')}"
      cmd = Mixlib::ShellOut.new(com, :timeout => 1200)
      cmd.run_command
      cmd.error!
    end
    
    def save
      File.open(File.join(store_path, 'vagabond.json'), 'w') do |file|
        file.write(JSON.dump(@config))
      end
    end

  end
end
