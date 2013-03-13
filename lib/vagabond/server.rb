require 'vagabond/vagabond'
require 'mixlib/cli'
require 'digest/md5'

module Vagabond
  
  class Server < Vagabond
        
    def initialize(me, actions)
      @name = me
      @base_template = 'ubuntu_1204' # TODO: Make this dynamic
      @action = actions.shift
      setup_ui
      load_configurations
      Config[:disable_auto_provision] = true
    end
    
    def stop
      if(lxc.exists?)
        if(lxc.running?)
          ui.info 'Shutting down Chef server container...'
          lxc.shutdown
          ui.info 'Chef server container shut down!'
        else
          ui.error 'Chef server container not currently running'
        end
      else
        ui.error 'Chef server container has not been created'
      end
    end

    def auto_upload
      ui.info 'Auto uploading all assets to local Chef server...'
      upload_roles
      upload_databags
      upload_environments
      upload_cookbooks
      ui.info ui.color('  -> All assets uploaded!', :green)
    end

    def upload_roles
      am_uploading('roles') do
        com = "knife role from file #{File.join(base_dir, 'roles/*')} #{Config[:knife_opts]}"
        debug(com)
        cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug])
        cmd.run_command
        cmd.error!
      end
    end

    def upload_databags
      am_uploading('data bags') do
        Dir.glob(File.join(base_dir, "data_bags/*")).each do |b|
          next if %w(. ..).include?(b)
          coms = [
            "knife data bag create #{File.basename(b)} #{Config[:knife_opts]}",
            "knife data bag from file #{File.basename(b)} #{Config[:knife_opts]} --all"
          ].each do |com|
            debug(com)
            cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug])
            cmd.run_command
            cmd.error!
          end
        end
      end
    end

    def upload_environments
      am_uploading('environments') do
        com = "knife environment from file #{File.join(base_dir, 'environments/*')} #{Config[:knife_opts]}"
        debug(com)
        cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug])
        cmd.run_command
        cmd.error!
      end
    end

    def upload_cookbooks
      am_uploading('cookbooks') do
        if(vagabondfile[:local_chef_server][:berkshelf])
          berks_upload
        else
          raw_upload
        end
      end
    end

    private

    def am_uploading(thing)
      ui.info "#{ui.color('Local chef server:', :bold)} Uploading #{ui.color(thing, :green)}"
      yield
      ui.info ui.color("  -> UPLOADED #{thing.upcase}", :green)
    end

    def write_berks_config
      path = File.join(vagabond_dir, 'berks.json')
      if(File.exists?(path))
        cur = Mash.new(JSON.load(File.read(path)))
      else
        cur = Mash.new
      end
      url = "https://#{lxc.container_ip(10, true)}"
      if(cur[:chef].nil? || cur[:chef][:chef_server_url] != url)
        cur[:chef] = Mash.new(:chef_server_url => url)
        cur[:ssl] = Mash.new(:verify => false)
        File.open(path, 'w') do |file|
          file.write(JSON.dump(cur))
        end
      end
    end
    
    def generated_name
      unless(@_gn)
        s = Digest::MD5.new
        s << vagabondfile.path
        @_gn = "server-#{s.hexdigest}"
      end
      @_gn
    end

    def do_create
      com = "#{Config[:sudo]}lxc-clone -n #{generated_name} -o #{@base_template}"
      debug(com)
      cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug])
      cmd.run_command
      cmd.error!
      @lxc = Lxc.new(generated_name)
      @internal_config[:mappings][name] = generated_name
      @internal_config.save
      ui.info ui.color('  -> Chef Server container created!', :cyan)
      lxc.start
      ui.info ui.color('  -> Bootstrapping erchef...', :cyan)
      tem_file = File.expand_path(File.join(File.dirname(__FILE__), 'bootstraps/server.erb'))
      com = "#{Config[:sudo]}knife bootstrap #{lxc.container_ip(10, true)} --template-file #{tem_file} -i /opt/hw-lxc-config/id_rsa"
      debug(com)
      cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug], :timeout => 1200)
      cmd.run_command
      cmd.error!
      ui.info ui.color('  -> Chef Server CREATED!', :green)
      auto_upload if vagabondfile[:local_chef_server][:auto_upload]
    end

    def berks_upload
      write_berks_config
      com = "berks upload -c #{File.join(vagabond_dir, 'berks.json')}"
      debug(com)
      cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug])
      cmd.run_command
      cmd.error!
      ui.info "Berks cookbook upload complete!"
    end

    def raw_upload
      com = "knife cookbook upload#{Config[:knife_opts]} --all"
      debug(com)
      cmd = Mixlib::ShellOut.new(com, :live_stream => Config[:debug])
      cmd.run_command
      cmd.error!
      ui.info "Cookbook upload complete!"
    end

  end
end
